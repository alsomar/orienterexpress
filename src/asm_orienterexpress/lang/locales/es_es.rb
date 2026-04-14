# frozen_string_literal: true

module ASM_Extensions
  module OrienterExpress
    module Lang
      def self.locale_es_es
        {
          commands: {
            oevertex: {
              label:            "Colocación en vértices de arista",
              tooltip:          "Colocación en vértices de arista",
              status:           "Coloca copias orientadas en ambos vértices de cada arista, con desfase opcional hacia el interior.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Clic sobre componente de muestra",
              no_geometry_hint: "Clic en aristas o caras para colocar copias en sus vértices",
              vcb_hint:         "Ctrl: añadir a la selección  |  Shift: punto de inserción (%<ip>s)  |  Tab: eje de orientación (%<axis>s)  |  Alt: modo (%<mode>s)  |  ←/→: ajustar desfase (%<offset>s)  |  ↑/↓: ajustar giro (%<roll>s)"
            },
            oecenter: {
              label:            "Colocación centrada en arista",
              tooltip:          "Colocación centrada en arista",
              status:           "Coloca copias centradas sobre las aristas con desfase opcional.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Clic sobre componente de muestra",
              no_geometry_hint: "Clic en aristas/caras para colocar copias a mitad de arista",
              vcb_hint:         "Ctrl: añadir a la selección  |  Shift: punto de inserción (%<ip>s)  |  Tab: eje de orientación (%<axis>s)  |  Alt: modo (%<mode>s)  |  ←/→: ajustar desfase (%<offset>s)  |  ↑/↓: ajustar giro (%<roll>s)"
            },
            oezscale: {
              label:            "Escalado en Z",
              tooltip:          "Escalado en Z",
              status:           "Escala y coloca copias a lo largo de las aristas con un desfase en cada vértice.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Clic sobre componente de muestra",
              no_geometry_hint: "Clic en aristas/caras para orientar y escalar copias en un eje",
              vcb_hint:         "Ctrl: añadir a la selección  |  Shift: punto de inserción (%<ip>s)  |  Tab: eje de escala (%<axis>s)  |  Alt: modo (%<mode>s)  |  ←/→: ajustar desfase (%<offset>s)  |  ↑/↓: ajustar giro (%<roll>s)"
            },
            oeuscale: {
              label:            "Escalado uniforme",
              tooltip:          "Escalado uniforme",
              status:           "Escala uniformemente y coloca copias a lo largo de las aristas.",
              no_sample_hint:   "Clic sobre componente de muestra",
              no_geometry_hint: "Clic en aristas/caras para orientar y escalar copias uniformemente",
              vcb_hint:         "Ctrl: añadir a la selección  |  Alt: modo (%<mode>s)  |  ↑/↓: ajustar giro (%<roll>s)"
            },
            oeflow: {
              label:            "Colocación según flujo de vértices",
              tooltip:          "Colocación según flujo de vértices",
              status:           "Coloca copias orientadas en vértices, alineadas al flujo de las aristas entrantes.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Clic sobre componente de muestra",
              no_geometry_hint: "Clic en aristas/caras para colocar copias en sus vértices",
              vcb_hint:         "Ctrl: añadir a la selección  |  Shift: punto de inserción (%<ip>s)  |  Tab: eje de orientación (%<axis>s)  |  Alt: modo (%<mode>s)  |  ←/→: ajustar desfase (%<offset>s)  |  ↑/↓: ajustar giro (%<roll>s)"
            },
            oesurface: {
              label:            "Colocación en superficie",
              tooltip:          "Colocación en superficie",
              status:           "Coloca copias en el centro de cada grupo de superficie suave, con desfase a lo largo de la normal promedio.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Clic sobre componente de muestra",
              no_geometry_hint: "Clic sobre caras para colocar copias",
              vcb_hint:         "Ctrl: añadir a la selección  |  Shift: punto de inserción (%<ip>s)  |  Tab: eje de orientación (%<axis>s)  |  Alt: orientación (%<orient>s)  |  ←/→: ajustar desfase (%<offset>s)  |  ↑/↓: ajustar giro (%<roll>s)",
              axis_parallel:    "paralelo a arista dominante",
              axis_perp:        "perpendicular a arista dominante",
              axis_ground:      "horizontal"
            },
            oealignoptimal: {
              label:    "Optimizar Bounding Box",
              tooltip:  "Optimizar Bounding Box",
              status:   "Reorienta los ejes del componente para minimizar el volumen del bounding box.",
              vcb_hint: "Clic: optimizar  |  Esc: salir"
            },
            oereset: {
              label:    "Resetear rotaciones",
              tooltip:  "Resetear rotaciones",
              status:   "Resetea la rotación de las entidades seleccionadas a los ejes globales.",
              vcb_hint: "Tab: cambiar pivote  |  Esc: cancelar"
            },
            settings: {
              label:   "Ajustes de #{EXT_NAME}",
              tooltip: "Ajustes de #{EXT_NAME}",
              status:  "Abrir los ajustes de #{EXT_NAME}."
            }
          },

          html: {
            settings: {
              title:              "Ajustes",
              tooltip:            "Ajustes",
              dark_mode_tooltip:  "Cambiar a modo claro",
              light_mode_tooltip: "Cambiar a modo oscuro",
              general_options:    "Opciones generales",
              language_selection: "Selección de idioma",
              language_hint:      "Puede ser necesario reiniciar SketchUp para aplicar los ajustes de idioma.",
              system_language:    "(idioma del sistema)",
              context_menu:       "Mostrar menú contextual",
              reset_button:       "Mostrar botón de reinicio",
              reset_settings:     "Restablecer ajustes",
              reset_confirm_body: "Esto restablecerá todos los ajustes a sus valores predeterminados. ¿Estás seguro?",
              reset_confirm_yes:  "Sí, restablecer",
              reset_confirm_no:   "Cancelar",
              rotation_mode:   "Rotación",
              rotation_ground: "Suelo",
              rotation_flow:   "Flujo",
              rotation_normal: "Normal",
              insertion_point:        "Punto de inserción",
              insertion_base_short:   "base",
              insertion_center_short: "centro",
              insertion_origin_short: "origen",
              steps:          "Magnitudes",
              roll_step:      "Incremento de giro",
              offset_step:    "Incremento de desfase",
              default_roll:   "Giro por defecto",
              default_offset: "Desfase por defecto",
              smooth_groups:  "Tratar superficies suavizadas como una única cara"
            },
            about: {
              title:       "Info",
              tooltip:     "Info",
              version:     "Versión ",
              designed_by: "Diseñado y desarrollado por #{LINK_ALEJANDRO}.",
              uses:        "Esta extensión utiliza #{LINK_MODUS}.",
              warning:     "<b>¡#{EXT_NAME} es gratis!</b> Confía sólo en #{LINK_EXT_WAREHOUSE} y #{LINK_SKETCHUCATION} para descargarlo de forma segura."
            },
            thanks: {
              title:   "Gracias",
              tooltip: "Gracias",
              txt1:    "Gracias a las comunidades de #{LINK_SKP_FORUMS} y #{LINK_SUC_FORUMS} por compartir su conocimiento y tender la mano a nuevos desarrolladores.",
              txt2:    "El apoyo de la comunidad es lo que hace posible proyectos como #{EXT_NAME}. Si puedes, considera contribuir a través de #{LINK_PATREON} o #{LINK_KOFI}.",
              txt3:    "¡Gracias por tu generosidad!",
              txt4:    "Atentamente,"
            }
          }

        }.freeze
      end
    end
  end
end
