# frozen_string_literal: true

# Clerk SDK config. secret_key falls back to ENV['CLERK_SECRET_KEY'].
# The Rack middleware is auto-mounted when the SDK is required, which
# reads the __session cookie set by accounts.bloombilt.com on the apex
# .bloombilt.com domain and exposes the verified user via the `clerk`
# helper in controllers that include Clerk::Authenticatable.
#
# Signers never sign in, so the signing routes skip the middleware. Without
# this, a signer who is also logged into another Bloombilt app carries a
# Clerk __session cookie that expires a minute after the page loads; the
# middleware then answers every later fetch with a 307 handshake redirect
# and the form can't save or complete.
Clerk.configure do |c|
  c.logger = Rails.logger
  c.excluded_routes = %w[
    /s/*
    /d/*
    /p/*
    /e/*
    /submitters/*
    /file/*
    /blobs_proxy/*
    /preview/*
    /success
    /resubmit_form
    /submit_form_email_2fa
    /start_form_email_2fa_send
    /send_submission_email
    /send_submission_email.json
    /api/attachments
    /api/submitter_email_clicks
    /api/submitter_form_views
  ]
end
