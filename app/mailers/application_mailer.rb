class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('FROM_EMAIL', 'no-reply@99staples.com')
  layout 'mailer'
end
