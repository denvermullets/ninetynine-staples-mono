import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "video",
    "canvas",
    "nameCanvas",
    "setCanvas",
    "captureButton",
    "scanButton",
    "retakeButton",
    "results",
    "loading",
    "preview",
    "previewImage",
    "status",
    "collectionSelect",
    "scanHistory",
    "cameraError",
    "cameraContainer",
    "progress",
    "progressBar",
    "progressText",
    "cardGuide",
    "stabilityIndicator",
    "autoModeToggle",
    "debugPanel",
    "debugNameText",
    "debugSetText",
    "debugParsedSet",
    "debugParsedNumber",
  ];

  static values = {
    searchPath: String,
    addPath: String,
    autoMode: { type: Boolean, default: true },
  };

  // Magic card aspect ratio: 63mm x 88mm ≈ 0.716
  static CARD_ASPECT_RATIO = 63 / 88;
  // Stability detection settings
  static STABILITY_THRESHOLD = 15; // Pixel difference threshold
  static STABILITY_FRAMES = 20; // Frames to consider stable (~0.7 seconds at 30fps)
  static CHECK_INTERVAL = 50; // ms between stability checks

  connect() {
    this.stream = null;
    this.tesseract = null;
    this.worker = null;
    this.isScanning = false;
    this.stabilityCheckInterval = null;
    this.previousFrameData = null;
    this.stableFrameCount = 0;
    this.isAutoCapturing = false;
  }

  disconnect() {
    this.stopCamera();
    this.stopStabilityDetection();
    this.terminateWorker();
  }

  toggleAutoMode() {
    this.autoModeValue = !this.autoModeValue;
    this.updateAutoModeUI();

    if (this.autoModeValue && this.stream) {
      this.startStabilityDetection();
    } else {
      this.stopStabilityDetection();
    }
  }

  updateAutoModeUI() {
    if (this.hasAutoModeToggleTarget) {
      this.autoModeToggleTarget.classList.toggle("bg-accent-50", this.autoModeValue);
      this.autoModeToggleTarget.classList.toggle("bg-gray-600", !this.autoModeValue);
    }

    // Show/hide manual buttons based on mode
    if (this.hasCaptureButtonTarget) {
      this.captureButtonTarget.classList.toggle("hidden", this.autoModeValue && this.stream);
    }
  }

  async startCamera() {
    try {
      this.hideError();
      this.updateStatus("Requesting camera access...");

      const constraints = {
        video: {
          facingMode: { ideal: "environment" }, // Prefer back camera on mobile
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      };

      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      this.videoTarget.srcObject = this.stream;
      await this.videoTarget.play();

      this.showCameraView();
      this.updateCardGuide();
      this.updateAutoModeUI();

      if (this.autoModeValue) {
        this.updateStatus("Position card in the guide. Hold still to auto-capture.");
        this.startStabilityDetection();
      } else {
        this.updateStatus("Camera ready. Position your card and capture.");
      }
    } catch (error) {
      this.handleCameraError(error);
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
    this.stopStabilityDetection();
  }

  updateCardGuide() {
    if (!this.hasCardGuideTarget || !this.hasVideoTarget) return;

    // Calculate card guide dimensions based on video container
    const container = this.cameraContainerTarget;
    const containerRect = container.getBoundingClientRect();
    const containerWidth = containerRect.width;
    const containerHeight = containerRect.height;

    // Card should fill ~70% of the smaller dimension
    const padding = 0.15; // 15% padding on each side
    const availableWidth = containerWidth * (1 - padding * 2);
    const availableHeight = containerHeight * (1 - padding * 2);

    let cardWidth, cardHeight;
    const aspectRatio = this.constructor.CARD_ASPECT_RATIO;

    // Fit card within available space maintaining aspect ratio
    if (availableWidth / availableHeight > aspectRatio) {
      // Height constrained
      cardHeight = availableHeight;
      cardWidth = cardHeight * aspectRatio;
    } else {
      // Width constrained
      cardWidth = availableWidth;
      cardHeight = cardWidth / aspectRatio;
    }

    const guide = this.cardGuideTarget;
    guide.style.width = `${cardWidth}px`;
    guide.style.height = `${cardHeight}px`;
    guide.style.left = `${(containerWidth - cardWidth) / 2}px`;
    guide.style.top = `${(containerHeight - cardHeight) / 2}px`;
  }

  // Stability detection for auto-capture
  startStabilityDetection() {
    if (this.stabilityCheckInterval) return;

    this.previousFrameData = null;
    this.stableFrameCount = 0;

    this.stabilityCheckInterval = setInterval(() => {
      this.checkStability();
    }, this.constructor.CHECK_INTERVAL);
  }

  stopStabilityDetection() {
    if (this.stabilityCheckInterval) {
      clearInterval(this.stabilityCheckInterval);
      this.stabilityCheckInterval = null;
    }
    this.previousFrameData = null;
    this.stableFrameCount = 0;
    this.updateStabilityIndicator(0);
  }

  checkStability() {
    if (!this.stream || this.isScanning || this.isAutoCapturing) return;

    const video = this.videoTarget;
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");

    // Use smaller sample for performance
    const sampleWidth = 160;
    const sampleHeight = 120;
    canvas.width = sampleWidth;
    canvas.height = sampleHeight;

    ctx.drawImage(video, 0, 0, sampleWidth, sampleHeight);
    const currentFrameData = ctx.getImageData(0, 0, sampleWidth, sampleHeight).data;

    if (this.previousFrameData) {
      const diff = this.calculateFrameDifference(currentFrameData, this.previousFrameData);

      if (diff < this.constructor.STABILITY_THRESHOLD) {
        this.stableFrameCount++;
        this.updateStabilityIndicator(this.stableFrameCount / this.constructor.STABILITY_FRAMES);

        if (this.stableFrameCount >= this.constructor.STABILITY_FRAMES) {
          this.autoCapture();
        }
      } else {
        this.stableFrameCount = 0;
        this.updateStabilityIndicator(0);
      }
    }

    this.previousFrameData = currentFrameData;
  }

  calculateFrameDifference(current, previous) {
    let totalDiff = 0;
    const pixelCount = current.length / 4;

    // Sample every 10th pixel for performance
    for (let i = 0; i < current.length; i += 40) {
      const rDiff = Math.abs(current[i] - previous[i]);
      const gDiff = Math.abs(current[i + 1] - previous[i + 1]);
      const bDiff = Math.abs(current[i + 2] - previous[i + 2]);
      totalDiff += (rDiff + gDiff + bDiff) / 3;
    }

    return totalDiff / (pixelCount / 10);
  }

  updateStabilityIndicator(progress) {
    if (this.hasStabilityIndicatorTarget) {
      const percent = Math.min(100, Math.round(progress * 100));
      this.stabilityIndicatorTarget.style.width = `${percent}%`;

      // Change color as it gets closer to capture
      if (percent > 80) {
        this.stabilityIndicatorTarget.classList.remove("bg-yellow-500", "bg-accent-50");
        this.stabilityIndicatorTarget.classList.add("bg-green-500");
      } else if (percent > 40) {
        this.stabilityIndicatorTarget.classList.remove("bg-accent-50", "bg-green-500");
        this.stabilityIndicatorTarget.classList.add("bg-yellow-500");
      } else {
        this.stabilityIndicatorTarget.classList.remove("bg-yellow-500", "bg-green-500");
        this.stabilityIndicatorTarget.classList.add("bg-accent-50");
      }
    }
  }

  async autoCapture() {
    if (this.isAutoCapturing || this.isScanning) return;

    this.isAutoCapturing = true;
    this.stopStabilityDetection();

    this.updateStatus("Card detected! Capturing...");

    // Brief delay for visual feedback
    await new Promise((resolve) => setTimeout(resolve, 200));

    this.capture();

    // Auto-scan after capture
    await this.scan();

    this.isAutoCapturing = false;
  }

  capture() {
    if (!this.stream) return;

    const video = this.videoTarget;
    const canvas = this.canvasTarget;
    const ctx = canvas.getContext("2d");

    // Set canvas dimensions to match video
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    // Draw video frame to canvas
    ctx.drawImage(video, 0, 0);

    // Show preview
    this.previewImageTarget.src = canvas.toDataURL("image/png");
    this.showPreviewView();
    this.updateStatus("Image captured. Click 'Scan Text' to process.");
  }

  retake() {
    this.showCameraView();
    this.clearResults();
    this.clearDebugPanel();

    if (this.autoModeValue) {
      this.updateStatus("Position card in the guide. Hold still to auto-capture.");
      this.startStabilityDetection();
    } else {
      this.updateStatus("Position your card and capture.");
    }
  }

  updateDebugPanel(nameText, setText, setCode, cardNumber) {
    if (this.hasDebugPanelTarget) {
      this.debugPanelTarget.classList.remove("hidden");
    }
    if (this.hasDebugNameTextTarget) {
      this.debugNameTextTarget.textContent = nameText || "(empty)";
    }
    if (this.hasDebugSetTextTarget) {
      this.debugSetTextTarget.textContent = setText || "(empty)";
    }
    if (this.hasDebugParsedSetTarget) {
      this.debugParsedSetTarget.textContent = setCode || "(not found)";
    }
    if (this.hasDebugParsedNumberTarget) {
      this.debugParsedNumberTarget.textContent = cardNumber || "(not found)";
    }
  }

  clearDebugPanel() {
    if (this.hasDebugPanelTarget) {
      this.debugPanelTarget.classList.add("hidden");
    }
  }

  async scan() {
    if (this.isScanning) return;
    this.isScanning = true;

    try {
      this.showLoading();
      this.updateStatus("Loading OCR engine...");

      await this.initializeTesseract();

      this.updateStatus("Extracting text regions...");
      const { nameImageData, setImageData } = this.extractRegions();

      // Run OCR on both regions in parallel
      this.updateStatus("Scanning card name...");
      const [nameResult, setResult] = await Promise.all([
        this.recognizeText(nameImageData, "name"),
        this.recognizeText(setImageData, "set"),
      ]);

      const nameText = nameResult?.data?.text?.trim() || "";
      const setText = setResult?.data?.text?.trim() || "";

      console.log("OCR Results - Name:", nameText, "Set:", setText);

      // Parse set code and collector number
      const { setCode, cardNumber } = this.parseSetAndNumber(setText);

      // Update debug panel
      this.updateDebugPanel(nameText, setText, setCode, cardNumber);

      this.updateStatus("Searching database...");
      await this.searchCard(setCode, cardNumber, nameText);
    } catch (error) {
      console.error("Scan error:", error);
      this.showError("Scan failed. Please try again with better lighting.");
    } finally {
      this.isScanning = false;
      this.hideLoading();
    }
  }

  extractRegions() {
    const canvas = this.canvasTarget;
    const ctx = canvas.getContext("2d");
    const { width, height } = canvas;

    // Name region: top 15% of card
    const nameHeight = Math.floor(height * 0.15);
    const nameImageData = ctx.getImageData(0, 0, width, nameHeight);

    // Create canvas for name region
    const nameCanvas = this.nameCanvasTarget;
    nameCanvas.width = width;
    nameCanvas.height = nameHeight;
    nameCanvas.getContext("2d").putImageData(nameImageData, 0, 0);

    // Set/number region: bottom 10%, left 40%
    const setHeight = Math.floor(height * 0.10);
    const setWidth = Math.floor(width * 0.40);
    const setY = Math.floor(height * 0.90);
    const setImageData = ctx.getImageData(0, setY, setWidth, setHeight);

    // Create canvas for set region
    const setCanvas = this.setCanvasTarget;
    setCanvas.width = setWidth;
    setCanvas.height = setHeight;
    setCanvas.getContext("2d").putImageData(setImageData, 0, 0);

    return {
      nameImageData: nameCanvas.toDataURL("image/png"),
      setImageData: setCanvas.toDataURL("image/png"),
    };
  }

  async initializeTesseract() {
    if (this.worker) return;

    // Dynamic import of Tesseract.js
    const Tesseract = await import("tesseract.js");
    this.tesseract = Tesseract;

    this.worker = await Tesseract.createWorker("eng", 1, {
      logger: (m) => {
        if (m.status === "recognizing text") {
          this.updateProgress(Math.round(m.progress * 100));
        }
      },
    });
  }

  async recognizeText(imageData, region) {
    if (!this.worker) return null;

    try {
      const result = await this.worker.recognize(imageData);
      return result;
    } catch (error) {
      console.error(`OCR error for ${region}:`, error);
      return null;
    }
  }

  async terminateWorker() {
    if (this.worker) {
      await this.worker.terminate();
      this.worker = null;
    }
  }

  parseSetAndNumber(text) {
    if (!text) return { setCode: null, cardNumber: null };

    // Clean up OCR artifacts
    const cleaned = text
      .toUpperCase()
      .replace(/[^A-Z0-9\s/·.-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    console.log("Parsing set text:", cleaned);

    // Common formats:
    // "MKM · 123/287"
    // "MKM 123/287"
    // "MKM-123"
    // "123/287 MKM"
    // "MKM · EN · 123"

    // Try to find set code (2-4 uppercase letters)
    const setCodeMatch = cleaned.match(/\b([A-Z]{2,5})\b/);
    const setCode = setCodeMatch ? setCodeMatch[1] : null;

    // Try to find collector number (digits, possibly with /total)
    const numberMatch = cleaned.match(/\b(\d{1,4})(?:\/\d+)?\b/);
    const cardNumber = numberMatch ? numberMatch[1] : null;

    console.log("Parsed - Set:", setCode, "Number:", cardNumber);

    return { setCode, cardNumber };
  }

  async searchCard(setCode, cardNumber, nameText) {
    const params = new URLSearchParams();

    if (setCode && cardNumber) {
      params.append("set_code", setCode);
      params.append("card_number", cardNumber);
    }

    if (nameText) {
      // Clean name text for search
      const cleanedName = this.cleanNameForSearch(nameText);
      if (cleanedName) {
        params.append("q", cleanedName);
      }
    }

    if (!params.toString()) {
      this.showError("Could not extract card information. Try better lighting or angle.");
      return;
    }

    try {
      const response = await fetch(`${this.searchPathValue}?${params.toString()}`, {
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);
      this.updateStatus("Search complete.");
    } catch (error) {
      console.error("Search error:", error);
      this.showError("Search failed. Please try again.");
    }
  }

  cleanNameForSearch(text) {
    if (!text) return null;

    // Take only the first line (card name is usually on one line)
    const firstLine = text.split("\n")[0];

    // Remove common OCR artifacts and clean up
    return firstLine
      .replace(/[^a-zA-Z0-9\s,'-]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  async addToCollection(event) {
    event.preventDefault();

    const button = event.currentTarget;
    const cardId = button.dataset.cardId;
    const cardUuid = button.dataset.cardUuid;
    const collectionId = this.collectionSelectTarget.value;

    if (!collectionId) {
      alert("Please select a collection first.");
      return;
    }

    const formData = new FormData();
    formData.append("magic_card_id", cardId);
    formData.append("card_uuid", cardUuid);
    formData.append("collection_id", collectionId);
    formData.append("quantity", 1);
    formData.append("foil_quantity", 0);

    try {
      button.disabled = true;
      button.textContent = "Adding...";

      const response = await fetch(this.addPathValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          Accept: "text/vnd.turbo-stream.html",
        },
        body: formData,
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      button.textContent = "Added!";
      setTimeout(() => {
        button.textContent = "Add";
        button.disabled = false;
      }, 1500);
    } catch (error) {
      console.error("Add error:", error);
      button.textContent = "Add";
      button.disabled = false;
      alert("Failed to add card. Please try again.");
    }
  }

  async addFoilToCollection(event) {
    event.preventDefault();

    const button = event.currentTarget;
    const cardId = button.dataset.cardId;
    const cardUuid = button.dataset.cardUuid;
    const collectionId = this.collectionSelectTarget.value;

    if (!collectionId) {
      alert("Please select a collection first.");
      return;
    }

    const formData = new FormData();
    formData.append("magic_card_id", cardId);
    formData.append("card_uuid", cardUuid);
    formData.append("collection_id", collectionId);
    formData.append("quantity", 0);
    formData.append("foil_quantity", 1);

    try {
      button.disabled = true;
      button.textContent = "Adding...";

      const response = await fetch(this.addPathValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          Accept: "text/vnd.turbo-stream.html",
        },
        body: formData,
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      button.textContent = "Added!";
      setTimeout(() => {
        button.textContent = "Foil";
        button.disabled = false;
      }, 1500);
    } catch (error) {
      console.error("Add error:", error);
      button.textContent = "Foil";
      button.disabled = false;
      alert("Failed to add card. Please try again.");
    }
  }

  // UI Helper Methods
  showCameraView() {
    this.cameraContainerTarget.classList.remove("hidden");
    this.previewTarget.classList.add("hidden");
    this.captureButtonTarget.classList.remove("hidden");
    this.scanButtonTarget.classList.add("hidden");
    this.retakeButtonTarget.classList.add("hidden");
  }

  showPreviewView() {
    this.cameraContainerTarget.classList.add("hidden");
    this.previewTarget.classList.remove("hidden");
    this.captureButtonTarget.classList.add("hidden");
    this.scanButtonTarget.classList.remove("hidden");
    this.retakeButtonTarget.classList.remove("hidden");
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden");
    }
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove("hidden");
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden");
    }
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add("hidden");
    }
  }

  updateProgress(percent) {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percent}%`;
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${percent}%`;
    }
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message;
    }
  }

  showError(message) {
    if (this.hasCameraErrorTarget) {
      this.cameraErrorTarget.textContent = message;
      this.cameraErrorTarget.classList.remove("hidden");
    }
    this.updateStatus(message);
  }

  hideError() {
    if (this.hasCameraErrorTarget) {
      this.cameraErrorTarget.classList.add("hidden");
    }
  }

  clearResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = "";
    }
  }

  handleCameraError(error) {
    console.error("Camera error:", error);

    let message;
    switch (error.name) {
      case "NotAllowedError":
        message = "Camera access was denied. Please allow camera access in your browser settings and refresh the page.";
        break;
      case "NotFoundError":
        message = "No camera found on this device.";
        break;
      case "NotReadableError":
        message = "Camera is already in use by another application.";
        break;
      case "OverconstrainedError":
        message = "Camera does not meet the required constraints.";
        break;
      case "SecurityError":
        message = "Camera access requires a secure connection (HTTPS).";
        break;
      default:
        message = `Camera error: ${error.message}`;
    }

    this.showError(message);
  }
}
