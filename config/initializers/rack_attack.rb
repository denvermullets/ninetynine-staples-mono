Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# Throttle signup attempts by IP — 1 per hour
Rack::Attack.throttle('sign_up/ip', limit: 5, period: 1.hour) do |req|
  req.ip if req.path == '/sign_up' && req.post?
end

# Throttle login attempts by IP — 10 per 15 minutes
Rack::Attack.throttle('login/ip', limit: 10, period: 15.minutes) do |req|
  req.ip if req.path == '/login' && req.post?
end

# Throttle password reset by IP — 3 per hour
Rack::Attack.throttle('password_resets/ip', limit: 3, period: 1.hour) do |req|
  req.ip if req.path == '/password_resets' && req.post?
end

# Throttle password reset by email — 3 per hour
Rack::Attack.throttle('password_resets/email', limit: 3, period: 1.hour) do |req|
  req.params.dig('user', 'email').to_s.strip.downcase.presence if req.path == '/password_resets' && req.post?
end

THROTTLED_HTML = <<~HTML.freeze
  <!DOCTYPE html>
  <html>
  <head>
    <title>Too Many Requests</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <style>
      body {
        background-color: #141e22;
        color: #fefefe;
        font-family: system-ui, -apple-system, sans-serif;
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        margin: 0;
      }
      .container { text-align: center; max-width: 480px; padding: 2rem; }
      h1 { font-size: 3rem; margin-bottom: 0.5rem; }
      p { color: #859296; font-size: 1.125rem; line-height: 1.6; }
      a { color: #39db7d; text-decoration: none; }
      a:hover { text-decoration: underline; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>429</h1>
      <p>You're doing that too often. Please wait a bit and try again.</p>
      <p><a href="/">Back to home</a></p>
    </div>
  </body>
  </html>
HTML

Rack::Attack.throttled_responder = lambda do |_request|
  [429, { 'Content-Type' => 'text/html', 'Retry-After' => '60' }, [THROTTLED_HTML]]
end
