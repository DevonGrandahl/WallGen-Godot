@tool class_name WallGen extends Node

enum OpeningTypes {None, Doorway, Window}

@export var start: Vector3 = Vector3.ZERO
@export var end: Vector3 = Vector3.FORWARD * 3
@export var regenHz = 2.0
@export var createCollider: bool = false

var meshInstance: MeshInstance3D
var collider: StaticBody3D
var colShape: CollisionShape3D

@export_category("Optional Handles")
## Optional field for a handle that can set the start position
@export var startHandle: Node3D
## Optional field for a handle that can set the end position
@export var endHandle: Node3D
@export var snap: bool = true


@export_category("Dimensions")
@export var wallWidth: float = 0.15
@export var wallHeight: float = 2.33
@export var bottomTrim: bool = true
@export var topTrim: bool = false
@export var trimWidth = .025
@export var trimHeight = .1

@export_category("Door & Window Settings")
@export var openingType: OpeningTypes = OpeningTypes.None
@export var openingWidth: float = 1
@export var openingTop: float = 2.1
@export var openingBottomHeight: float = 1
@export var openingTrim: bool = true
@export_range(.2, 1, .1) var openingTrimMultiplier: float = .8

@export_category("Colors and Materials")
@export var trimColor: Color = Color.WHITE
@export var wallColor: Color = Color.SKY_BLUE
@export var customWallMaterial: StandardMaterial3D 

@export_group("Action Buttons")
@export var createNextWall: bool:
	set(value):
		var dir = (self.end - self.start).normalized()
		generateNextWall(self.end + dir)
@export var splitWallInHalf: bool:
	set(value):
		var focus = splitWall((start + end) / 2)
		

var regenRemainingWait = .1
var root: Node

# For generating via script
static func construct(start, end, wallColor = Color.SKY_BLUE, trimColor = Color.WHITE, openingType = OpeningTypes.None, createCollider = false, openingWidth = 1, wallWidth = .15, wallHeight = 2.33, bottomTrim = true, topTrim = false, trimWidth = .025, trimHeight = .1, customWallMaterial = null) -> WallGen:
	var instance = WallGen.new()
	
	if (start is Node3D):
		instance.startHandle = start
	elif (start is Vector3):
		instance.start = start
		
	if (end is Node3D):
		instance.endHandle = end
	elif (end is Vector3):
		instance.end = end
	
	instance.openingType = openingType; instance.createCollider = createCollider; instance.openingWidth = openingWidth; instance.wallWidth = wallWidth; instance.wallHeight = wallHeight; instance.bottomTrim = bottomTrim; instance.topTrim = topTrim; instance.trimWidth = trimWidth; instance.trimColor = trimColor; instance.wallColor = wallColor; instance.customWallMaterial = customWallMaterial;
	instance.name = "Wall"
	return instance
	
static func constructCopy(start, end, source: WallGen, openingType = OpeningTypes.None) -> WallGen:
	var instance = WallGen.new()
	
	if (start is Node3D):
		instance.startHandle = start
	elif (start is Vector3):
		instance.start = start
		
	if (end is Node3D):
		instance.endHandle = end
	elif (end is Vector3):
		instance.end = end
	
	instance.openingType = openingType; instance.createCollider = source.createCollider; instance.openingWidth = source.openingWidth; instance.wallWidth = source.wallWidth; instance.wallHeight = source.wallHeight; instance.bottomTrim = source.bottomTrim; instance.topTrim = source.topTrim; instance.trimWidth = source.trimWidth; instance.trimColor = source.trimColor; instance.wallColor = source.wallColor; instance.customWallMaterial = source.customWallMaterial; instance.snap = source.snap;
	instance.name = "Wall"
	instance.regenHz = source.regenHz
	return instance

func _ready():		
	gen()

	
func verifyDependencies():
	if Engine.is_editor_hint():
		root = EditorInterface.get_edited_scene_root()
	else: 
		root = get_tree().get_root()
	
	if (!meshInstance):
		if self.get_child(0) is MeshInstance3D:
			meshInstance = self.get_child(0)
		else: 
			meshInstance = MeshInstance3D.new()
			self.add_child(meshInstance)
			meshInstance.set_owner(root)
			meshInstance.name = "Mesh"
		
	if (startHandle):
		start = startHandle.global_position
		if snap:
			start = start.snapped(Vector3(.2, .2, .2))
	
	if (endHandle):
		end = endHandle.global_position
		if snap:
			end = end.snapped(Vector3(.2, .2, .2))
	
func _process(delta):
			
	if (regenRemainingWait <= 0 && regenHz > 0):
		gen()
		regenRemainingWait = 1 / regenHz
	else:
		regenRemainingWait -= delta	

func gen():
	verifyDependencies()
	
	var center = (start + end) / 2
	
	
	# Calculate important vectors
	var direction = end - start
	var length = direction.length()
	var up = Vector3.UP
	var right = up.cross(direction).normalized()
	up = direction.cross(right).normalized()
	var openingCenter = lerp(self.start, self.end, .5)

	var h = up * wallHeight
	var ht = up * trimHeight
	var htTop = (up * (wallHeight + .001)) - (up * trimHeight)
	var hoTop = up * openingTop
	var w = (right * wallWidth * 0.5)
	
	var openingWidth = min(openingWidth, length - (trimHeight * openingTrimMultiplier * 2))
	
	if length == 0:
		return
	
	# Corners
	var corners = getCorners()
	var cornerStartLeft = corners[0]
	var cornerEndLeft = corners[1]
	var cornerEndRight = corners[2]
	var cornerStartRight = corners[3]
	
	# Trim Corners
	var trimCorners = getTrimCorners()
	var trimCornerStartLeft = trimCorners[0]
	var trimCornerEndLeft = trimCorners[1]
	var trimCornerEndRight = trimCorners[2]
	var trimCornerStartRight = trimCorners[3]
	
	# Opening corners
	var openingStartLeft = openingCenter - (direction.normalized() * openingWidth * .5) + w
	var openingStartRight = openingCenter - (direction.normalized() * openingWidth * .5) - w
	var openingEndLeft = openingCenter + (direction.normalized() * openingWidth * .5) + w
	var openingEndRight = openingCenter + (direction.normalized() * openingWidth * .5) - w
	
	# Opening Trim Corners
	var trimOpeningMiddleStartLeft = openingStartLeft + (direction.normalized() * trimWidth) + (right * trimWidth)
	var trimOpeningMiddleStartRight = openingStartRight + (direction.normalized() * trimWidth) + (-right * trimWidth)
	var trimOpeningMiddleEndLeft = openingEndLeft - (direction.normalized() * trimWidth) + (right * trimWidth)
	var trimOpeningMiddleEndRight = openingEndRight - (direction.normalized() * trimWidth) + (-right * trimWidth)
	var hot = (up * openingTop) - (up * .001) # Height Opening Top
	var hob = (up * openingBottomHeight) # Height Opening Bottom
	var trimWidthAroundOpening = direction.normalized() * trimHeight * openingTrimMultiplier


	# Set Up Mesh Arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	
	var trimArrays = []
	trimArrays.resize(Mesh.ARRAY_MAX)
	trimArrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	trimArrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	trimArrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	trimArrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()



	# Do the generation
	if topTrim && trimHeight > 0: #Top Trim
		generateCube(trimCornerStartLeft + htTop, trimCornerEndLeft + htTop, trimCornerEndRight + htTop, trimCornerStartRight + htTop, trimArrays, ht, true)

	##################### FLAT WALL ##########################
	if openingType == OpeningTypes.None:   # Wall
		generateCube(cornerStartLeft, cornerEndLeft, cornerEndRight, cornerStartRight, arrays, h)

		if bottomTrim && trimHeight > 0: # Bottom Trim
			generateCube(trimCornerStartLeft, trimCornerEndLeft, trimCornerEndRight, trimCornerStartRight, trimArrays, ht, true)


	#################### DOOR WAY ###########################
	
	if openingType == OpeningTypes.Doorway:   # Wall
		var openingRatio = openingWidth / length
		var wallRatio = 1 - openingRatio
		generateCube(cornerStartLeft, openingStartLeft, openingStartRight, cornerStartRight, arrays, h, false, Vector4(0, wallRatio / 2, 0, 1))
		generateCube(openingEndLeft, cornerEndLeft, cornerEndRight, openingEndRight, arrays, h, false, Vector4(1 - (wallRatio / 2), 1, 0, 1))
		generateCube(openingStartLeft + hoTop, openingEndLeft + hoTop, openingEndRight + hoTop, openingStartRight + hoTop, arrays, h - hoTop, true, Vector4(wallRatio / 2, 1 - (wallRatio / 2), 0, (wallHeight - openingTop) / wallHeight))

		if bottomTrim && trimHeight > 0:   # Wall Trim
			generateCube(trimCornerStartLeft, trimOpeningMiddleStartLeft, trimOpeningMiddleStartRight, trimCornerStartRight, trimArrays, ht, true)
			generateCube(trimOpeningMiddleEndLeft, trimCornerEndLeft, trimCornerEndRight, trimOpeningMiddleEndRight, trimArrays, ht, true)
		
		if openingTrim:   # Opening Trim
			generateCube(trimOpeningMiddleEndLeft + hot, trimOpeningMiddleEndRight + hot, trimOpeningMiddleStartRight + hot, trimOpeningMiddleStartLeft + hot, trimArrays, ht * openingTrimMultiplier, true)
			generateCube(trimOpeningMiddleStartLeft, trimOpeningMiddleStartRight, trimOpeningMiddleStartRight - trimWidthAroundOpening, trimOpeningMiddleStartLeft - trimWidthAroundOpening, trimArrays, hot + (ht * openingTrimMultiplier), false)
			generateCube(trimOpeningMiddleEndLeft, trimOpeningMiddleEndLeft + trimWidthAroundOpening, trimOpeningMiddleEndRight + trimWidthAroundOpening, trimOpeningMiddleEndRight, trimArrays, hot + (ht * openingTrimMultiplier), false)

	#################### WINDOW ##########################
	if openingType == OpeningTypes.Window:   # Wall Trim
		var openingRatio = openingWidth / length
		var wallRatio = 1 - openingRatio
		generateCube(cornerStartLeft, openingStartLeft, openingStartRight, cornerStartRight, arrays, h, false, Vector4(0, wallRatio / 2, 0, 1))
		generateCube(openingEndLeft, cornerEndLeft, cornerEndRight, openingEndRight, arrays, h, false, Vector4(1 - (wallRatio / 2), 1, 0, 1))
		generateCube(openingStartLeft + hoTop, openingEndLeft + hoTop, openingEndRight + hoTop, openingStartRight + hoTop, arrays, h - hoTop, true, Vector4(wallRatio / 2, 1 - (wallRatio / 2), 0, 1 - (openingTop / wallHeight)))
		generateCube(openingStartLeft, openingEndLeft, openingEndRight, openingStartRight, arrays, hob, false, Vector4(wallRatio / 2, 1 - (wallRatio / 2), 1 - (openingBottomHeight / wallHeight), 1))
		
		if bottomTrim && trimHeight > 0:   # Opening Trim
			generateCube(trimCornerStartLeft, trimCornerEndLeft, trimCornerEndRight, trimCornerStartRight, trimArrays, ht, true)
		
		if openingTrim:
			var hobWindowTrim = hob - (ht * (openingTrimMultiplier - .001))
			generateCube(trimOpeningMiddleEndLeft + hot, trimOpeningMiddleEndRight + hot, trimOpeningMiddleStartRight + hot, trimOpeningMiddleStartLeft + hot, trimArrays, ht * openingTrimMultiplier, true)
			generateCube(trimOpeningMiddleEndLeft + hobWindowTrim, trimOpeningMiddleEndRight + hobWindowTrim, trimOpeningMiddleStartRight + hobWindowTrim, trimOpeningMiddleStartLeft + hobWindowTrim, trimArrays, ht * openingTrimMultiplier, true)
			
			generateCube(trimOpeningMiddleStartLeft + hobWindowTrim, trimOpeningMiddleStartRight + hobWindowTrim, trimOpeningMiddleStartRight - trimWidthAroundOpening + hobWindowTrim, trimOpeningMiddleStartLeft - trimWidthAroundOpening + hobWindowTrim, trimArrays, hot - hobWindowTrim + (ht * openingTrimMultiplier), true)
			generateCube(trimOpeningMiddleEndLeft + hobWindowTrim, trimOpeningMiddleEndLeft + trimWidthAroundOpening + hobWindowTrim, trimOpeningMiddleEndRight + trimWidthAroundOpening + hobWindowTrim, trimOpeningMiddleEndRight + hobWindowTrim, trimArrays, hot - hobWindowTrim + (ht * openingTrimMultiplier), true)





	# Generate wall bridges. Only do one direction to avoid duplicate faces and z-fighting
	for child in get_parent().get_children():
		if child is WallGen:
			var otherStart = child.start
				
			if otherStart == self.end:
				var nextWall = child
				var nextWallCorners = nextWall.getCorners()
				var nextWallTrimCorners = nextWall.getTrimCorners()
				generateCube(cornerEndLeft, nextWallCorners[0], nextWallCorners[3], cornerEndRight, arrays, h)
				if bottomTrim && trimHeight > 0:
					generateCube(trimCornerEndLeft, nextWallTrimCorners[0], nextWallTrimCorners[3], trimCornerEndRight, trimArrays, ht, true)	
				if topTrim && trimHeight > 0:
					generateCube(trimCornerEndLeft + htTop, nextWallTrimCorners[0] + htTop, nextWallTrimCorners[3] + htTop, trimCornerEndRight + htTop, trimArrays, ht, true)	
				
	
	# Start finalizing the mesh
	var arrayMesh = ArrayMesh.new()
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	meshInstance.mesh = arrayMesh
	
	# Colliders
	for c in meshInstance.get_children():
		c.name = "OldCollider"
		c.queue_free()
		
	if createCollider:
		meshInstance.create_trimesh_collision()
		meshInstance.get_child(meshInstance.get_child_count() - 1).name = "Collider"
	
	# Wall Material
	var wallMat = StandardMaterial3D.new()
	wallMat.albedo_color = wallColor
	if (customWallMaterial):
		wallMat = customWallMaterial
	
	arrayMesh.surface_set_material(0, wallMat)
	
	# Add trim surface
	if (bottomTrim || topTrim):
		arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trimArrays)
		var trimMat = StandardMaterial3D.new()
		trimMat.albedo_color = trimColor
		trimMat.metallic_specular = 2
		arrayMesh.surface_set_material(1, trimMat)
	
	meshInstance.mesh = arrayMesh

func generateCube(southWest, northWest, northEast, southEast, arrays, h, generateBottom = false, UVMatrix = null):
	var direction = (southWest - northWest).normalized()
	var up = Vector3.UP
	var right = up.cross(direction).normalized()
	up = direction.cross(right).normalized()
	
	# One side shows UVs backwards, so we have to flip the matrix
	var flippedUVMatrix = null
	if UVMatrix:
		flippedUVMatrix = Vector4(UVMatrix.y, UVMatrix.x, UVMatrix.z, UVMatrix.w)
	
	generateQuad(
		northWest,
		northWest + h, 
		southWest + h,
		southWest,
		up.cross(northWest - southWest).normalized(),
		arrays,
		flippedUVMatrix
	)
	
	generateQuad(
		northEast,
		northEast + h,
		northWest + h,
		northWest,
		-direction,
		arrays,
	)
	
	generateQuad(
		southEast,
		southEast + h,
		northEast + h,
		northEast,
		-up.cross(northEast - southEast).normalized(),
		arrays,
		UVMatrix
	)
	
	generateQuad(
		southWest,
		southWest + h,
		southEast + h,
		southEast,
		direction,
		arrays
	)
	
	generateQuad(
		southWest + h,
		northWest + h,
		northEast + h,
		southEast + h,
		up,
		arrays
	)
	
	if generateBottom:
		generateQuad(
			southEast,
			northEast,
			northWest,
			southWest,
			-up,
			arrays
		)
	
	return

func generateQuad(southWest, northWest, northEast, southEast, n, arrays, UVMatrix = null):
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var indices = arrays[Mesh.ARRAY_INDEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indexOffset = vertices.size()
	
	var UVXmin = UVMatrix.x if UVMatrix else 0
	var UVXmax = UVMatrix.y if UVMatrix else 1
	var UVYmin = UVMatrix.z if UVMatrix else 0
	var UVYmax = UVMatrix.w if UVMatrix else 1
	
	
	# Vertices
	vertices.append(southWest) # 0 BL
	vertices.append(northWest) # 1 UL
	vertices.append(northEast) # 2 UR
	vertices.append(southEast) # 3 BR
	
	## Normals (one per vertex)
	normals.append(n)  
	normals.append(n)
	normals.append(n) 
	normals.append(n) 
	
	## Faces
	indices.append(indexOffset + 0)
	indices.append(indexOffset + 1)
	indices.append(indexOffset + 2)
	
	indices.append(indexOffset + 0)
	indices.append(indexOffset + 2)
	indices.append(indexOffset + 3) 
	
	### UVs
	uvs.append(Vector2(UVXmin, UVYmax))  # BL
	uvs.append(Vector2(UVXmin, UVYmin))  # UL
	uvs.append(Vector2(UVXmax, UVYmin))  # UR
	uvs.append(Vector2(UVXmax, UVYmax))  # BR
	
func getCorners():
	var direction = end - start
	var length = direction.length()
	var up = Vector3.UP
	var right = up.cross(direction).normalized()
	up = direction.cross(right).normalized()
	
	var w = (right * wallWidth * 0.5)
	var h = up * wallHeight
	
	var cornerStartLeft = start + w 
	var cornerEndLeft = end + w
	var cornerEndRight = end - w
	var cornerStartRight = start - w
	
	return [cornerStartLeft, cornerEndLeft, cornerEndRight, cornerStartRight]
	
func getTrimCorners():
	var direction = end - start
	var up = Vector3.UP
	var right = up.cross(direction).normalized()
	up = direction.cross(right).normalized()
	
	var w = (right * wallWidth * 0.5)
	var wt = w + (right * trimWidth)
	var ht = up * trimHeight
	
	var trimCornerStartLeft = start + wt - (direction.normalized() * trimWidth)
	var trimCornerEndLeft = end + wt + (direction.normalized() * trimWidth)
	var trimCornerEndRight = (end - wt) + (direction.normalized() * trimWidth)
	var trimCornerStartRight = (start - wt) - (direction.normalized() * trimWidth)
	
	return [trimCornerStartLeft, trimCornerEndLeft, trimCornerEndRight, trimCornerStartRight]
			
func splitWall(position: Vector3, gap: float = 0, insertWall: bool = false, insertWallOpening: OpeningTypes = OpeningTypes.None):
	var direction = (position - start).normalized()
	var length: float = (end - start).length()
	
	gap = min(gap, length)
	
	var newWall = WallGen.constructCopy(position + (direction * gap * .5), self.end, self)
	self.end = position - (direction * gap * .5)
	self.endHandle = null
	self.get_parent().add_child(newWall)
	newWall.set_owner(root)
	newWall.name = "Wall"
	
	if insertWall:
		var insertedWall = WallGen.constructCopy(position - (direction * gap * .5), position + (direction * gap * .5), self)
		self.get_parent().add_child(insertedWall)
		insertedWall.set_owner(root)
		insertedWall.name = "Wall"
		
	
	gen()	
		
func generateNextWall(newEnd: Vector3):
	var newStartHandle
	var newEndHandle
	if endHandle:
		newStartHandle = endHandle
	else:
		newStartHandle = Marker3D.new()
		newStartHandle.position = end
		self.get_parent().add_child(newStartHandle)
		newStartHandle.set_owner(root)
		newStartHandle.name = "Corner"
		
	newEndHandle = Marker3D.new()
	if newEnd:
		newEndHandle.position = newEnd
	else:
		newEndHandle.position = newStartHandle.position + Vector3.FORWARD
		
	self.get_parent().add_child(newEndHandle)
	newEndHandle.set_owner(root)
	
		
	var newWall = WallGen.constructCopy(newStartHandle, newEndHandle, self)
	self.get_parent().add_child(newWall)
	newWall.set_owner(root)
	newWall.name = "Wall"
	newEndHandle.name = "Corner"
	
	return newWall
