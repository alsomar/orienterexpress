module ASM_Extensions
  module OrienterExpress
    module Lang

      def self.init
        Sketchup.require "asm_orienterexpress/lang/i18n"
        true
      end

    end # module Lang
  end # module OrienterExpress
end # module ASM_Extensions

ASM_Extensions::OrienterExpress::Lang.init
