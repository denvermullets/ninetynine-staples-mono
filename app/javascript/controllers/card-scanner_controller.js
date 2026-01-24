import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "video",
    "canvas",
    "nameCanvas",
    "setCanvas",
    "results",
    "loading",
    "preview",
    "previewImage",
    "status",
    "collectionSelect",
    "scanHistory",
    "cameraError",
    "cameraContainer",
    "cardGuide",
    "processingLog",
    "logEntries",
    "scanToggle",
    "scanToggleText",
    "debugNamePreview",
    "debugSetPreview",
    "debugNamePlaceholder",
    "debugSetPlaceholder",
  ];

  static values = {
    searchPath: String,
    addPath: String,
  };

  // Magic card aspect ratio: 63mm x 88mm ≈ 0.716
  static CARD_ASPECT_RATIO = 63 / 88;
  // Continuous scan interval (ms) - how often to try OCR
  static SCAN_INTERVAL = 2000;

  connect() {
    this.stream = null;
    this.worker = null;
    this.isScanning = false;
    this.isInitializing = false;
    this.continuousScanInterval = null;
    this.isPaused = false;
    this.logCounter = 0;
    this.isRotated = false;
  }

  disconnect() {
    this.stopCamera();
    this.stopContinuousScan();
    this.terminateWorker();
  }

  async startCamera() {
    try {
      this.hideError();
      this.log("system", "Requesting camera access...");

      const constraints = {
        video: {
          facingMode: { ideal: "environment" },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      };

      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      this.videoTarget.srcObject = this.stream;
      await this.videoTarget.play();

      this.log("success", "Camera started successfully");
      this.showCameraView();
      this.updateCardGuide();
      this.updateStatus("Camera ready. Click 'Start Scanning' to begin continuous scan.");
    } catch (error) {
      this.handleCameraError(error);
    }
  }

  stopCamera() {
    this.stopContinuousScan();
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
  }

  rotateCamera() {
    this.isRotated = !this.isRotated;
    this.videoTarget.style.transform = this.isRotated ? "rotate(180deg)" : "";
    this.log("system", `Camera rotated ${this.isRotated ? "180°" : "back to normal"}`);
  }

  toggleScanning() {
    if (this.continuousScanInterval) {
      this.stopContinuousScan();
      this.log("system", "Scanning paused by user");
    } else {
      this.startContinuousScan();
    }
  }

  async startContinuousScan() {
    if (this.continuousScanInterval || !this.stream || this.isInitializing) {
      this.log("warning", "Cannot start scanning - already running or initializing");
      return;
    }

    this.isPaused = false;
    this.updateScanToggleUI(true);
    this.log("system", "Starting continuous scan mode...");
    this.updateStatus("Scanning... Point camera at a Magic card");

    // Initialize Tesseract if needed
    if (!this.worker) {
      this.isInitializing = true;
      try {
        await this.initializeTesseract();
      } catch (error) {
        this.isInitializing = false;
        this.updateScanToggleUI(false);
        this.updateStatus("Failed to initialize OCR. Please refresh and try again.");
        return;
      }
      this.isInitializing = false;
    }

    // Start continuous scanning
    this.continuousScanInterval = setInterval(() => {
      this.performScan();
    }, this.constructor.SCAN_INTERVAL);

    // Do first scan immediately
    this.performScan();
  }

  stopContinuousScan() {
    if (this.continuousScanInterval) {
      clearInterval(this.continuousScanInterval);
      this.continuousScanInterval = null;
    }
    this.updateScanToggleUI(false);
  }

  updateScanToggleUI(isScanning) {
    if (this.hasScanToggleTarget) {
      if (isScanning) {
        this.scanToggleTarget.classList.remove("bg-accent-50");
        this.scanToggleTarget.classList.add("bg-red-500");
      } else {
        this.scanToggleTarget.classList.remove("bg-red-500");
        this.scanToggleTarget.classList.add("bg-accent-50");
      }
    }
    if (this.hasScanToggleTextTarget) {
      this.scanToggleTextTarget.textContent = isScanning ? "Stop Scanning" : "Start Scanning";
    }
  }

  async performScan() {
    if (this.isScanning || this.isPaused || !this.stream) return;
    this.isScanning = true;

    const scanId = ++this.logCounter;
    this.log("scan", `--- Scan #${scanId} started ---`);

    try {
      // Capture current frame
      this.log("capture", "Capturing video frame...");
      this.captureFrame();

      // Extract regions
      this.log("ocr", "Extracting name and set regions...");
      const { nameImageData, setImageData } = this.extractRegions();

      // Run OCR on both regions
      this.log("ocr", "Running OCR on name region (top 15%)...");
      const nameResult = await this.recognizeText(nameImageData, "name");
      const nameText = nameResult?.data?.text?.trim() || "";
      this.log("data", `Name OCR result: "${nameText.substring(0, 100)}${nameText.length > 100 ? '...' : ''}"`);

      this.log("ocr", "Running OCR on set region (bottom-left)...");
      const setResult = await this.recognizeText(setImageData, "set");
      const setText = setResult?.data?.text?.trim() || "";
      this.log("data", `Set OCR result: "${setText}"`);

      // Parse set code and collector number
      const { setCode, cardNumber } = this.parseSetAndNumber(setText);
      this.log("parse", `Parsed: Set="${setCode || 'none'}", Number="${cardNumber || 'none'}"`);

      // Clean name for search
      const cleanedName = this.cleanNameForSearch(nameText);
      this.log("parse", `Cleaned name for search: "${cleanedName || 'none'}"`);

      // Check if we have enough data to search
      if (!setCode && !cardNumber && !cleanedName) {
        this.log("warning", "No usable text found - skipping search");
        return;
      }

      // Search database
      this.log("search", `Querying database...`);
      const params = new URLSearchParams();
      if (setCode && cardNumber) {
        params.append("set_code", setCode);
        params.append("card_number", cardNumber);
        this.log("query", `Exact search: set_code=${setCode}, card_number=${cardNumber}`);
      }
      if (cleanedName) {
        params.append("q", cleanedName);
        this.log("query", `Name search: q=${cleanedName}`);
      }

      const response = await fetch(`${this.searchPathValue}?${params.toString()}`, {
        headers: {
          Accept: "text/html",
          "Turbo-Frame": "scan_results",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
      });

      const html = await response.text();

      // Check if we got results (look for the result card class in the response)
      if (html.includes('bg-background/50')) {
        // Found a match! Pause and show results
        const resultsFrame = document.getElementById("scan_results");
        resultsFrame.innerHTML = html;

        // Count results for logging
        const resultCount = (html.match(/bg-background\/50/g) || []).length;
        this.log("success", `Found ${resultCount} matching card(s)!`);
        this.pauseAndShowResults();
      } else {
        this.log("warning", "No matching cards found in database");
      }
    } catch (error) {
      this.log("error", `Scan error: ${error.message}`);
      console.error("Scan error:", error);
    } finally {
      this.isScanning = false;
    }
  }

  pauseAndShowResults() {
    // Stop continuous scanning
    this.stopContinuousScan();
    this.isPaused = true;

    // Show the captured frame as preview
    this.previewImageTarget.src = this.canvasTarget.toDataURL("image/png");
    this.showPreviewView();

    this.log("system", "Scanning paused - card found! Click 'Scan Next' to continue.");
    this.updateStatus("Card found! Add to collection or click 'Scan Next' to continue.");
  }

  scanNext() {
    this.isPaused = false;
    this.showCameraView();
    this.clearResults();
    this.startContinuousScan();
  }

  captureFrame() {
    const video = this.videoTarget;
    const canvas = this.canvasTarget;
    const ctx = canvas.getContext("2d");

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    if (this.isRotated) {
      // Rotate the canvas 180 degrees to match the visual display
      ctx.save();
      ctx.translate(canvas.width, canvas.height);
      ctx.rotate(Math.PI);
      ctx.drawImage(video, 0, 0);
      ctx.restore();
    } else {
      ctx.drawImage(video, 0, 0);
    }
  }

  extractRegions() {
    const video = this.videoTarget;
    const canvas = this.canvasTarget;
    const ctx = canvas.getContext("2d");

    // Get card guide position (it's positioned relative to the container)
    const guide = this.cardGuideTarget;
    const container = this.cameraContainerTarget;
    const containerRect = container.getBoundingClientRect();

    // Guide dimensions in CSS pixels
    const guideLeft = parseFloat(guide.style.left) || 0;
    const guideTop = parseFloat(guide.style.top) || 0;
    const guideWidth = parseFloat(guide.style.width) || containerRect.width * 0.7;
    const guideHeight = parseFloat(guide.style.height) || containerRect.height * 0.7;

    // Scale from CSS pixels to video pixels
    const scaleX = video.videoWidth / containerRect.width;
    const scaleY = video.videoHeight / containerRect.height;

    const cardX = Math.floor(guideLeft * scaleX);
    const cardY = Math.floor(guideTop * scaleY);
    const cardWidth = Math.floor(guideWidth * scaleX);
    const cardHeight = Math.floor(guideHeight * scaleY);

    this.log("capture", `Card region: x=${cardX}, y=${cardY}, w=${cardWidth}, h=${cardHeight}`);

    // Extract the card region first
    const cardImageData = ctx.getImageData(cardX, cardY, cardWidth, cardHeight);

    // Create a temporary canvas for the card area
    const cardCanvas = document.createElement("canvas");
    cardCanvas.width = cardWidth;
    cardCanvas.height = cardHeight;
    const cardCtx = cardCanvas.getContext("2d");
    cardCtx.putImageData(cardImageData, 0, 0);

    // Name region: top 12% of CARD, skip left 5%, skip right 25% (avoid mana symbols)
    const nameHeight = Math.floor(cardHeight * 0.12);
    const nameLeft = Math.floor(cardWidth * 0.05);
    const nameWidth = Math.floor(cardWidth * 0.70); // 5% to 75%, skipping right 25%
    const nameImageData = cardCtx.getImageData(nameLeft, 0, nameWidth, nameHeight);

    const nameCanvas = this.nameCanvasTarget;
    nameCanvas.width = nameWidth;
    nameCanvas.height = nameHeight;
    const nameCtx = nameCanvas.getContext("2d");
    nameCtx.putImageData(nameImageData, 0, 0);

    // Preprocess name region for better OCR
    this.preprocessForOCR(nameCanvas);

    // Set/number region: bottom 6% of CARD (the actual collector info line), left 60%
    const setHeight = Math.floor(cardHeight * 0.06);
    const setWidth = Math.floor(cardWidth * 0.60);
    const setY = Math.floor(cardHeight * 0.94); // Very bottom
    const setImageData = cardCtx.getImageData(0, setY, setWidth, setHeight);

    const setCanvas = this.setCanvasTarget;
    setCanvas.width = setWidth;
    setCanvas.height = setHeight;
    const setCtx = setCanvas.getContext("2d");
    setCtx.putImageData(setImageData, 0, 0);

    // Preprocess set region for better OCR
    this.preprocessForOCR(setCanvas);

    const nameDataUrl = nameCanvas.toDataURL("image/png");
    const setDataUrl = setCanvas.toDataURL("image/png");

    // Update debug previews so we can see what's being OCR'd
    if (this.hasDebugNamePreviewTarget) {
      this.debugNamePreviewTarget.src = nameDataUrl;
      this.debugNamePreviewTarget.classList.remove("hidden");
      if (this.hasDebugNamePlaceholderTarget) {
        this.debugNamePlaceholderTarget.classList.add("hidden");
      }
    }
    if (this.hasDebugSetPreviewTarget) {
      this.debugSetPreviewTarget.src = setDataUrl;
      this.debugSetPreviewTarget.classList.remove("hidden");
      if (this.hasDebugSetPlaceholderTarget) {
        this.debugSetPlaceholderTarget.classList.add("hidden");
      }
    }

    return {
      nameImageData: nameDataUrl,
      setImageData: setDataUrl,
    };
  }

  // Preprocess image for better OCR results
  preprocessForOCR(canvas) {
    const ctx = canvas.getContext("2d");
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;

    // Convert to grayscale and increase contrast
    for (let i = 0; i < data.length; i += 4) {
      // Grayscale using luminance formula
      const gray = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];

      // Increase contrast (stretch histogram)
      const contrast = 1.5; // Contrast multiplier
      const factor = (259 * (contrast * 100 + 255)) / (255 * (259 - contrast * 100));
      const newGray = Math.min(255, Math.max(0, factor * (gray - 128) + 128));

      data[i] = newGray;     // R
      data[i + 1] = newGray; // G
      data[i + 2] = newGray; // B
      // Alpha unchanged
    }

    ctx.putImageData(imageData, 0, 0);
  }

  async initializeTesseract() {
    if (this.worker) return;

    // Check if Tesseract is loaded globally (via script tag)
    if (typeof Tesseract === "undefined") {
      this.log("error", "Tesseract.js not loaded! Make sure the script tag is present.");
      throw new Error("Tesseract.js not loaded");
    }

    this.log("ocr", "Creating Tesseract worker...");

    try {
      this.worker = await Tesseract.createWorker("eng", 1, {
        logger: (m) => {
          this.log("ocr", `${m.status}${m.progress ? ` (${Math.round(m.progress * 100)}%)` : ''}`);
        },
      });
      this.log("success", "Tesseract worker created successfully");
    } catch (error) {
      this.log("error", `Failed to create Tesseract worker: ${error.message}`);
      throw error;
    }
  }

  async recognizeText(imageData, region) {
    if (!this.worker) return null;

    try {
      // Use PSM 7 (single text line) for name, PSM 6 (block) for set
      // PSM modes: https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html
      const psm = region === "name" ? "7" : "6";

      await this.worker.setParameters({
        tessedit_pageseg_mode: psm,
        // Only allow alphanumeric and common punctuation
        tessedit_char_whitelist: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-',. ",
      });

      const result = await this.worker.recognize(imageData);
      return result;
    } catch (error) {
      this.log("error", `OCR error for ${region}: ${error.message}`);
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

    const cleaned = text
      .toUpperCase()
      .replace(/[^A-Z0-9\s/·.-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    // Try to find set code (2-5 uppercase letters)
    const setCodeMatch = cleaned.match(/\b([A-Z]{2,5})\b/);
    const setCode = setCodeMatch ? setCodeMatch[1] : null;

    // Try to find collector number
    const numberMatch = cleaned.match(/\b(\d{1,4})(?:\/\d+)?\b/);
    const cardNumber = numberMatch ? numberMatch[1] : null;

    return { setCode, cardNumber };
  }

  cleanNameForSearch(text) {
    if (!text) return null;

    const firstLine = text.split("\n")[0];
    const cleaned = firstLine
      .replace(/[^a-zA-Z0-9\s,'-]/g, "")
      .replace(/\s+/g, " ")
      .trim();

    // Only return if we have something meaningful (at least 3 chars)
    return cleaned.length >= 3 ? cleaned : null;
  }

  async addToCollection(event) {
    event.preventDefault();
    const button = event.currentTarget;
    await this.addCard(button, "regular");
  }

  async addFoilToCollection(event) {
    event.preventDefault();
    const button = event.currentTarget;
    await this.addCard(button, "foil");
  }

  async addProxyToCollection(event) {
    event.preventDefault();
    const button = event.currentTarget;
    await this.addCard(button, "proxy");
  }

  async addProxyFoilToCollection(event) {
    event.preventDefault();
    const button = event.currentTarget;
    await this.addCard(button, "proxy_foil");
  }

  async addCard(button, cardType) {
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
    formData.append("quantity", cardType === "regular" ? 1 : 0);
    formData.append("foil_quantity", cardType === "foil" ? 1 : 0);
    formData.append("proxy_quantity", cardType === "proxy" ? 1 : 0);
    formData.append("proxy_foil_quantity", cardType === "proxy_foil" ? 1 : 0);

    try {
      button.disabled = true;
      const originalText = button.textContent;
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

      const typeLabel = cardType === "regular" ? "" : ` (${cardType})`;
      this.log("success", `Added card to collection${typeLabel}`);

      button.textContent = "Added!";
      setTimeout(() => {
        button.textContent = originalText;
        button.disabled = false;
        // Auto-resume scanning after adding a card
        this.scanNext();
      }, 1000);
    } catch (error) {
      this.log("error", `Failed to add card: ${error.message}`);
      button.textContent = originalText;
      button.disabled = false;
    }
  }

  // Logging
  log(type, message) {
    if (!this.hasLogEntriesTarget) return;

    const timestamp = new Date().toLocaleTimeString();
    const typeColors = {
      system: "text-blue-400",
      success: "text-green-400",
      error: "text-red-400",
      warning: "text-yellow-400",
      ocr: "text-purple-400",
      scan: "text-cyan-400",
      capture: "text-gray-400",
      data: "text-orange-400",
      parse: "text-pink-400",
      search: "text-indigo-400",
      query: "text-teal-400",
    };

    const colorClass = typeColors[type] || "text-grey-text";
    const typeLabel = type.toUpperCase().padEnd(7);

    const entry = document.createElement("div");
    entry.className = "font-mono text-xs leading-relaxed";
    entry.innerHTML = `
      <span class="text-grey-text/50">${timestamp}</span>
      <span class="${colorClass} font-semibold">[${typeLabel}]</span>
      <span class="text-grey-text">${this.escapeHtml(message)}</span>
    `;

    this.logEntriesTarget.appendChild(entry);

    // Auto-scroll to bottom
    this.logEntriesTarget.scrollTop = this.logEntriesTarget.scrollHeight;

    // Keep only last 100 entries
    while (this.logEntriesTarget.children.length > 100) {
      this.logEntriesTarget.removeChild(this.logEntriesTarget.firstChild);
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  clearLog() {
    if (this.hasLogEntriesTarget) {
      this.logEntriesTarget.innerHTML = "";
    }
    this.log("system", "Log cleared");
  }

  // UI Helpers
  updateCardGuide() {
    if (!this.hasCardGuideTarget || !this.hasVideoTarget) return;

    const container = this.cameraContainerTarget;
    const containerRect = container.getBoundingClientRect();
    const containerWidth = containerRect.width;
    const containerHeight = containerRect.height;

    const padding = 0.15;
    const availableWidth = containerWidth * (1 - padding * 2);
    const availableHeight = containerHeight * (1 - padding * 2);

    let cardWidth, cardHeight;
    const aspectRatio = this.constructor.CARD_ASPECT_RATIO;

    if (availableWidth / availableHeight > aspectRatio) {
      cardHeight = availableHeight;
      cardWidth = cardHeight * aspectRatio;
    } else {
      cardWidth = availableWidth;
      cardHeight = cardWidth / aspectRatio;
    }

    const guide = this.cardGuideTarget;
    guide.style.width = `${cardWidth}px`;
    guide.style.height = `${cardHeight}px`;
    guide.style.left = `${(containerWidth - cardWidth) / 2}px`;
    guide.style.top = `${(containerHeight - cardHeight) / 2}px`;
  }

  showCameraView() {
    this.cameraContainerTarget.classList.remove("hidden");
    if (this.hasPreviewTarget) {
      this.previewTarget.classList.add("hidden");
    }
  }

  showPreviewView() {
    this.cameraContainerTarget.classList.add("hidden");
    if (this.hasPreviewTarget) {
      this.previewTarget.classList.remove("hidden");
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
    this.log("error", message);
  }

  hideError() {
    if (this.hasCameraErrorTarget) {
      this.cameraErrorTarget.classList.add("hidden");
    }
  }

  clearResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = '<p class="text-grey-text/70 text-sm">Scanning for cards...</p>';
    }
  }

  handleCameraError(error) {
    console.error("Camera error:", error);

    let message;
    switch (error.name) {
      case "NotAllowedError":
        message = "Camera access was denied. Please allow camera access in your browser settings.";
        break;
      case "NotFoundError":
        message = "No camera found on this device.";
        break;
      case "NotReadableError":
        message = "Camera is already in use by another application.";
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
