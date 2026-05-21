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
              no_sample_hint:   "Haz clic sobre un componente",
              no_geometry_hint: "Haz clic sobre una arista/cara",
              vcb_hint:         "SHIFT = pivote (%<ip>s)  |  TAB = eje de orientación (%<axis>s)  |  ALT = modo (%<mode>s)  |  ← = eje de desfase (%<offset_axis>s)  |  ↑ = sistema (%<frame>s)"
            },
            oecenter: {
              label:            "Colocación centrada en arista",
              tooltip:          "Colocación centrada en arista",
              status:           "Coloca copias centradas sobre las aristas con desfase opcional.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Haz clic sobre un componente",
              no_geometry_hint: "Haz clic sobre una arista/cara",
              vcb_hint:         "SHIFT = pivote (%<ip>s)  |  TAB = eje de orientación (%<axis>s)  |  ALT = modo (%<mode>s)  |  ← = eje de desfase (%<offset_axis>s)  |  ↑ = sistema (%<frame>s)"
            },
            oeaxisscale: {
              label:            "Escalado por eje",
              tooltip:          "Escalado por eje",
              status:           "Escala y coloca copias a lo largo de las aristas con un desfase en cada vértice.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Haz clic sobre un componente",
              no_geometry_hint: "Haz clic sobre una arista/cara",
              vcb_hint:         "SHIFT = pivote (%<ip>s)  |  TAB = eje de escala (%<axis>s)  |  ALT = modo (%<mode>s)  |  ← = eje de desfase (%<offset_axis>s)  |  ↑ = sistema (%<frame>s)"
            },
            oeuscale: {
              label:            "Escalado uniforme",
              tooltip:          "Escalado uniforme",
              status:           "Escala uniformemente y coloca copias a lo largo de las aristas con un desfase en cada vértice.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Haz clic sobre un componente",
              no_geometry_hint: "Haz clic sobre una arista/cara",
              vcb_hint:         "SHIFT = pivote (%<ip>s)  |  TAB = eje de escala (%<axis>s)  |  ALT = modo (%<mode>s)  |  ← = eje de desfase (%<offset_axis>s)  |  ↑ = sistema (%<frame>s)"
            },
            oeflow: {
              label:            "Colocación según flujo de vértices",
              tooltip:          "Colocación según flujo de vértices",
              status:           "Coloca copias orientadas en vértices, alineadas según el flujo de aristas.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Haz clic sobre un componente",
              no_geometry_hint: "Haz clic sobre una arista/cara",
              vcb_hint:         "SHIFT = pivote (%<ip>s)  |  TAB = eje de orientación (%<axis>s)  |  ALT = modo (%<mode>s)  |  ← = eje de desfase (%<offset_axis>s)  |  ↑ = sistema (%<frame>s)"
            },
            oesurface: {
              label:            "Colocación en superficie",
              tooltip:          "Colocación en superficie",
              status:           "Coloca copias en el centro de cada grupo de superficie suave, con desfase a lo largo de la normal promedio.",
              offset_prompt:    "Desfase",
              no_sample_hint:   "Haz clic sobre un componente",
              no_geometry_hint: "Haz clic sobre una cara",
              vcb_hint:         "SHIFT = pivote (%<ip>s)  |  TAB = eje de orientación (%<axis>s)  |  ALT = alineación (%<orient>s)  |  ← = eje de desfase (%<offset_axis>s)  |  ↑ = sistema (%<frame>s)",
              axis_parallel:    "dominante",
              axis_ground:      "horizontal"
            },
            oealigner: {
              label:                     "Alineador de ejes",
              tooltip:                   "Alineador de ejes",
              status:                    "Alinea los ejes de un componente/grupo según una arista/cara.",
              desc_entity:               "Haz clic sobre una arista/cara de un componente/grupo",
              desc_auto:                 "Haz clic sobre un componente",
              desc_reference_ref:        "Haz clic sobre una arista/cara o componente/grupo",
              desc_reference_target:     "Haz clic sobre un componente/grupo",
              vcb_hint_entity:           "CTRL + Clic = profundo (instancia interna)  |  TAB = eje (%<axis>s)  |  ALT = modo (%<mode>s)",
              vcb_hint_auto:             "ALT = modo (%<mode>s)",
              vcb_hint_reference_ref:    "TAB = eje (%<axis>s)  |  ALT = modo (%<mode>s)",
              vcb_hint_reference_target: "CTRL + Clic = fijar nueva referencia  |  TAB = eje (%<axis>s)  |  ALT = modo (%<mode>s)",
              mode_entity:    "entidad",
              mode_reference: "referencia",
              mode_auto:      "auto",
              axis_z:         "Z",
              axis_x:         "X",
              axis_y:         "Y"
            },
            oereset: {
              label:            "Resetear rotaciones",
              tooltip:          "Resetear rotaciones",
              status:           "Resetea la rotación de las entidades seleccionadas a los ejes globales.",
              no_geometry_hint: "Haz clic sobre un componente",
              vcb_hint:         "TAB = pivote (%<ip>s)  |  ESC = cancelar y salir"
            },
            tool_panel: {
              label:   "Panel de herramienta",
              tooltip: "Panel de herramienta",
              status:  "Muestra un panel flotante con los controles de la herramienta activa.",
              empty:   "Ninguna herramienta activa."
            },
            settings: {
              label:   "Ajustes de #{EXT_NAME}",
              tooltip: "Ajustes de #{EXT_NAME}",
              status:  "Abrir los ajustes de #{EXT_NAME}."
            }
          },

          errors: {
            invalid_sel:      "Selecciona al menos una o más aristas Y un grupo/componente.",
            invalid_face_sel: "Selecciona al menos una o más caras Y un grupo/componente.",
            no_entities:      "Selecciona al menos uno o más grupos/componentes."
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
              center_tool_panel:  "Centrar panel de herramienta en pantalla",
              reset_button:       "Mostrar botón de reinicio",
              reset_settings:     "Restablecer ajustes",
              reset_confirm_body: "Esto restablecerá todos los ajustes a sus valores predeterminados. ¿Estás seguro?",
              reset_confirm_yes:  "Sí, restablecer",
              reset_confirm_no:   "Cancelar",
              rotation_mode:   "Rotación",
              rotation_ground: "Suelo",
              rotation_flow:   "Flujo",
              rotation_normal: "Normal",
              pivot:              "Pivote",
              pivot_base_short:   "base",
              pivot_center_short: "centro",
              pivot_origin_short: "origen",
              axis:               "Eje de orientación",
              use_offset:         "Añadir <strong>desfase de posición</strong>",
              on:                 "Sí",
              off:                "No",
              offset_frame:       "Sistema de ejes",
              axes_world:         "Global",
              axes_local:         "Local",
              offset_x:           "Desfase X",
              offset_y:           "Desfase Y",
              offset_z:           "Desfase Z",
              offset_alignment:   "Desfase tangente",
              offset_normal:      "Desfase normal",
              steps:            "Magnitudes",
              roll_step:        "Incremento de <strong>giro</strong>",
              offset_step:      "Incremento de <strong>desfase</strong>",
              default_roll:     "<strong>Giro</strong> por defecto",
              default_offset_x: "<strong>Desfase X</strong> por defecto",
              default_offset_y: "<strong>Desfase Y</strong> por defecto",
              default_offset_z: "<strong>Desfase Z</strong> por defecto",
              remember_offset:  "Recordar <strong>desfase</strong>",
              remember_roll:    "Recordar <strong>giro</strong>",
              smooth_groups:    "Tratar superficies suavizadas como una única cara",
              ignore_soft_edges: "Ignorar aristas suavizadas"
            },
            tool_panel: {
              title:    "Herramientas",
              empty:    "vacío",
              sample:   "Muestra",
              geometry: "Geometría",
              edges:    "%<n>s aristas",
              faces:    "%<n>s caras",
              vertices: "%<n>s vértices",
              copies:   "%<n>s copias"
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
