class_name TerrainTextureLayer
extends Resource
## Configuration for a single terrain texture layer used by the splatmap shader.

@export var name: String = ""
@export var albedo_texture: Texture2D
@export var normal_texture: Texture2D
@export var roughness_texture: Texture2D
@export var metallic_texture: Texture2D
@export var uv_scale: float = 10.0  ## How many times the texture tiles per chunk
