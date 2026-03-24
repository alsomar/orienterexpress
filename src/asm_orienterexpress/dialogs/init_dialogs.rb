module ASM_Extensions
  module OrienterExpress
    module Dialogs

      def self.init
        Sketchup.require 'asm_orienterexpress/dialogs/settings_dialog'
        true
      end

    end # module Dialogs
  end # module OrienterExpress
end # module ASM_Extensions

ASM_Extensions::OrienterExpress::Dialogs.init
