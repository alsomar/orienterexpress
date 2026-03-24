module ASM_Extensions
  module OrienterExpress

    INFO_NAME    = EXTENSION[:name].to_s.freeze
    INFO_AUTHOR  = EXTENSION[:creator].to_s.freeze
    INFO_VERSION = EXTENSION[:version].to_s.freeze
    INFO_UPDATE  = EXTENSION[:update].to_s.freeze
    INFO_COPY    = "\u00A9 #{INFO_AUTHOR}, 2025"

    def self.format_update_date(locale = "en-US")
      parts = INFO_UPDATE.split("-").map(&:to_i)
      return INFO_UPDATE unless parts.length == 3 && parts[0] > 0

      year, month, day = parts
      months_long = {
        "en-US" => %w[January February March April May June July August September October November December],
        "es-ES" => %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
      }
      name = (months_long[locale] || months_long["en-US"])[month - 1]

      case locale
      when "es-ES"
        "#{day} de #{name} de #{year}"
      else
        "#{name} #{day}, #{year}"
      end
    rescue
      INFO_UPDATE
    end

  end # module OrienterExpress
end # module ASM_Extensions
