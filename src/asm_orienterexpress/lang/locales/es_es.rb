# frozen_string_literal: true

module ASM_Extensions
  module OrienterExpress
    module Lang
      def self.locale_es_es
        {
          commands: {
            oeedgevertex: {
              label:         "Colocación en vértices de arista",
              tooltip:       "Colocación en vértices de arista",
              status:        "Coloca copias orientadas en ambos vértices de cada arista, con desfase opcional hacia el interior.",
              offset_prompt: "Desfase",
              vcb_hint:      "Enter: actualizar  |  Tab: eje  |  End: modo  |  Home: inserción  |  ←→: ajustar  |  ↓: reiniciar  |  Esc: cancelar"
            },
            oecenter: {
              label:         "Colocación centrada en arista",
              tooltip:       "Colocación centrada en arista",
              status:        "Coloca copias centradas sobre las aristas con desfase opcional.",
              offset_prompt: "Desfase",
              vcb_hint:      "Enter: actualizar  |  Tab: eje  |  End: modo  |  Home: inserción  |  ←→: ajustar  |  ↓: reiniciar  |  Esc: cancelar"
            },
            oezscale: {
              label:          "Escalado en Z",
              tooltip:        "Escalado en Z",
              status:         "Escala y coloca copias a lo largo de las aristas con un desfase en cada vértice.",
              offset_prompt:  "Desfase",
              vcb_hint:       "Enter: actualizar  |  Tab: eje  |  End: modo  |  Home: inserción  |  ←→: ajustar  |  ↓: reiniciar  |  Esc: cancelar"
            },
            oeuscale: {
              label:   "Escalado uniforme",
              tooltip: "Escalado uniforme",
              status:  "Escala uniformemente y coloca copias a lo largo de las aristas."
            },
            oeflow: {
              label:          "Colocación según flujo de vértices",
              tooltip:        "Colocación según flujo de vértices",
              status:         "Coloca copias orientadas en vértices, alineadas al flujo de las aristas entrantes.",
              offset_prompt:  "Desfase",
              vcb_hint:       "Enter: actualizar  |  Tab: eje  |  End: modo  |  Home: inserción  |  ←→: ajustar  |  ↓: reiniciar  |  Esc: cancelar"
            },
            oeface: {
              label:         "Colocación en cara",
              tooltip:       "Colocación en cara",
              status:        "Coloca copias en el centroide de cada cara con un desfase a lo largo de la normal.",
              offset_prompt: "Desfase",
              vcb_hint:      "Enter: actualizar  |  Tab: eje  |  End: orientación  |  Home: inserción  |  ←→: ajustar  |  ↓: reiniciar  |  Esc: cancelar",
              axis_parallel: "paralelo a arista dominante",
              axis_perp:     "perpendicular a arista dominante",
              axis_ground:   "horizontal"
            },
            oealignoptimal: {
              label:    "Optimizar Bounding Box",
              tooltip:  "Optimizar Bounding Box",
              status:   "Reorienta los ejes del componente para minimizar el volumen del bounding box.",
              vcb_hint: "Click: optimizar  |  Esc: salir"
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
              insertion_origin_short: "origen"
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
