module ASM_Extensions
  module OrienterExpress

    def self.dynamic_component?(entity)
      return false unless entity.respond_to?(:attribute_dictionary)

      entity.attribute_dictionary("dynamic_attributes") ||
        (entity.respond_to?(:definition) &&
        entity.definition.attribute_dictionary("dynamic_attributes"))
    end

    def self.fix_dc(entity)
      begin
        require 'su_dynamiccomponents'
      rescue LoadError
      end

      return unless defined?($dc_observers)

      dc = $dc_observers.get_latest_class
      return unless dc
      return unless dynamic_component?(entity)

      instances = [entity]

      if entity.respond_to?(:entities)
        entity.entities.grep(Sketchup::ComponentInstance).each do |inst|
          instances << inst if dynamic_component?(inst)
        end
      end

      instances.each { |inst| dc.method(:redraw).call(inst, true, false) }
    end

  end # module OrienterExpress
end # module ASM_Extensions
