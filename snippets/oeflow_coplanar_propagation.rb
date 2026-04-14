# IDEA: oeflow — coplanar plane normal + BFS sign propagation
#
# PROBLEMA
# --------
# Vertices de borde en una superficie plana (ej. retícula en Y=238) obtienen
# direcciones diagonales in-plane del sum de vectores (ej. (-1,0,0)) en lugar
# de la normal del plano (0,-1,0).
#
# El vértice interior funciona bien cuando tiene una arista fuera del plano
# (la arista de profundidad cancela las 4 aristas in-plane y da (0,-1,0)).
# Los vértices de borde NO tienen esa arista y su suma da diagonal.
#
# SOLUCIÓN PROPUESTA
# ------------------
# Antes de calcular la suma de vectores, comprobar si TODOS los edges
# seleccionados de un vértice son coplanares.
#
#   Si coplanares  → usar la normal del plano como candidato (signo arbitrario)
#   Si no coplanar → usar suma de vectores como dirección fiable (comportamiento actual)
#
# El BFS de signo existente propaga el signo correcto desde los vértices
# fiables (con arista fuera del plano) hacia todos los candidatos coplanares
# conectados.
#
# LIMITACIÓN CONOCIDA
# -------------------
# Rompe vértices interiores entre esquinas de estructuras 3D (caso
# mencionado por el usuario). Los vértices que conectan dos planos distintos
# pueden tener todos sus edges coplanares EN CADA PLANO por separado, pero
# el algoritmo los clasifica erróneamente como coplanares globales.
#
# Hay que estudiar cómo distinguir entre:
#   a) Vértice en UN plano (coplanar correcto → usar normal del plano)
#   b) Vértice en ARISTA entre dos planos (necesita la suma de vectores)
#
# HELPERS NUEVOS NECESARIOS
# -------------------------

# Devuelve la normal del plano común si todos los dirs son coplanares.
# Devuelve nil si los dirs no son todos coplanares (o si son paralelos).
def coplanar_plane_normal(dirs)
  normal = nil
  dirs.combination(2) do |a, b|
    cross = a.cross(b)
    next if cross.length < 1e-3     # dirs paralelos — sin constraint
    cross_n = cross.normalize
    if normal.nil?
      normal = cross_n
    elsif normal.dot(cross_n).abs < 0.99  # planos inconsistentes
      return nil
    end
  end
  normal
end

# Devuelve la normal promedio de las caras conectadas a los edges dados.
def face_normal_from_edges(edges)
  face_normals  = []
  seen_face_ids = {}
  edges.each do |edge|
    edge.faces.each do |face|
      next if seen_face_ids[face.entityID]
      seen_face_ids[face.entityID] = true
      fn = face.normal
      next if fn.length < 1e-6
      fn = fn.normalize
      fn = fn.reverse if !face_normals.empty? && face_normals.first.dot(fn) < 0
      face_normals << fn
    end
  end
  return nil if face_normals.empty?
  fn_sum = Geom::Vector3d.new(face_normals.sum(&:x), face_normals.sum(&:y), face_normals.sum(&:z))
  fn_sum.length > 1e-6 ? fn_sum.normalize : nil
end

# LÓGICA DE all_vertex_flow_directions CON COPLANARIDAD
# (sustituye al bloque vertex_edges.each del método actual)
#
# vertex_edges.each do |vertex, edges|
#   dirs = [...] # igual que ahora
#
#   plane_n = coplanar_plane_normal(dirs)
#   if plane_n
#     fn = face_normal_from_edges(edges)
#     if fn
#       reliable[vertex] = fn        # caras presentes → signo correcto
#     else
#       candidates[vertex] = plane_n # sin caras → signo por BFS
#     end
#   else
#     sum = Geom::Vector3d.new(dirs.sum(&:x), dirs.sum(&:y), dirs.sum(&:z))
#     if sum.length > 1e-6
#       reliable[vertex] = sum.normalize
#     else
#       fn = face_normal_from_edges(edges)
#       reliable[vertex] = fn if fn
#     end
#   end
# end
