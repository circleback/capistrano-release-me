Dir[File.join(__dir__, "services", "**", "*.rb")].each {|file| require file }

load File.expand_path("../tasks/releaseme.rake", __FILE__)