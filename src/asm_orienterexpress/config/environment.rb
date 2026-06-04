module ASM_Extensions
  module OrienterExpress

    INFO_NAME    = "Orienter Express"
    INFO_AUTHOR  = "Alejandro Soriano"
    INFO_VERSION = EXTENSION[:version].to_s.freeze
    INFO_UPDATE  = EXTENSION[:update].to_s.freeze
    INFO_START   = EXTENSION[:dev_start].to_s.freeze

    # Copyright range: dev_start year (fallback 2023) to current year
    # (fallback "Now"), e.g. "2023-2026", "2026", or "2023-Now".
    year_match   = INFO_START[/\d{4}/]
    year_start   = year_match ? year_match.to_i : 2023
    year_current = Time.now.year rescue nil
    year_range   =
      if year_current.nil?
        "#{year_start}-Now"
      elsif year_current > year_start
        "#{year_start}-#{year_current}"
      else
        year_start.to_s
      end
    INFO_COPY    = "\u00A9 #{INFO_AUTHOR}, #{year_range}".freeze

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
