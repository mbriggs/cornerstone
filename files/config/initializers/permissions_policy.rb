# Be sure to restart your server when you modify this file.

# Define an application-wide HTTP Permissions-Policy header.
# Restricts access to browser features the app doesn't use.

Rails.application.config.permissions_policy do |policy|
  policy.camera      :none
  policy.gyroscope   :none
  policy.magnetometer :none
  policy.microphone  :none
  policy.usb         :none
  policy.fullscreen  :self
end
