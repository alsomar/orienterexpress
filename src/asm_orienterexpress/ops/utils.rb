module ASM_Extensions
  module OrienterExpress

    def self.check_selection(edges, targets)
      method_id = __method__

      if targets.empty? || edges.empty?
        missing = []
        missing << "entities" if targets.empty?
        missing << "edges"    if edges.empty?

        UI.messagebox(MESSAGES[:invalid_sel])
        Debug.log(self, method_id, "Invalid selection: missing #{missing.join(' & ')}")
        return false
      end

      true
    end

    def self.check_targets(targets)
      method_id = __method__

      if targets.empty?
        UI.messagebox(MESSAGES[:no_entities])
        Debug.log(self, method_id, "Invalid selection: missing entities")
        return false
      end

      true
    end

  end # module OrienterExpress
end # module ASM_Extensions
