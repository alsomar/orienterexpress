module ASM_Extensions
  module OrienterExpress

    def self.init_ops
      Sketchup.require 'asm_orienterexpress/ops/selection'
      Sketchup.require 'asm_orienterexpress/ops/utils'
      Sketchup.require 'asm_orienterexpress/ops/orients'
      true
    end

  end # module OrienterExpress
end # module ASM_Extensions

ASM_Extensions::OrienterExpress.init_ops
