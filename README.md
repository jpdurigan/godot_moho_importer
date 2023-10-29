# Godot Moho Importer
Godot plugin in GDScript for importing Moho animations for 3.3+.

Import **.mohoproj files** to the project and convert it into a single scene.

This plugin also adds two classes from Moho that may be useful besides importation: **SwitchLayer** and **SmartBone**.

Made with some help from [Daniel](https://github.com/eh-jogos) and [Eduardo](https://www.behance.net/eduardow).

![Example of usage in game](https://github.com/jpdurigan/godot_moho_importer/blob/main/example.gif "Example of usage in game")

Some caveats you should know:

This plugin has some issues and is tuned to import a certain kind of Moho scene. It may work with others, but it was made to work with our workflow at that time. I tried to describe it below as best as I can.

I don't really plan on expanding it, as I don't have access to Moho anymore, but feel free to reach me if you need any help!


## 🛠️ Supported Moho features

- Skeleton animation
- Switch Layer
- Smart Bones and Actions
- Groups and Group mask
- Reparent animation
- Target bone and IK

#### Not implemented:
- Keyframe types: BOUNCE, CYCLE, ELASTIC, NOISY and POSE
- Masking modes: "Subtract" and "Clear + Add" modes
- Bone dynamics
- Point deformation

## 📖 How to use it

- Import your Moho animation into a Godot project, as a **.mohoproj file**.
	- To get the .mohoproj from a .moho file, you have to unarchive it (like a .zip file).
- To set Sprite textures, you need to create a folder named "images" in the same directory as the .mohoproj file (or you can set a custom folder in the import options).
- This plugin works better with a single animation/rig per file. If you have multiple animations for the same character, save each animation as a different file, import them into Godot and then merge them with Scene Merger.
- You should bind your layers to bones, as this plugin does not handle point deformation.
- Works best with a single skeleton per file, but it can import multiple skeletons.
- This plugin comes with Skeleton2DIK, a custom node for solving IK in Node2Ds using FABRIK. It performs poorly in runtime, so we recommend you bake it into the animation resource.

### Scene structure

Final scene structure is meant to mimic Moho's:
- Bone Layers become Skeleton2D nodes and its Bone2D children.
	- Bone/Layer binding is done by RemoteTransform2D nodes.
	- Reparent animation also uses RemoteTransform2D.
- Every layer inside a Bone Layer is child of a Node2D, sibling to the Skeleton2D.
- Mesh and Image Layers become Sprites.
- Groups become Node2D and group masks are done using Light2Ds.
- Switch Layers are a custom class that inherits Node2D.

All animation is saved as a external resource, as well as on the main scene's AnimationPlayer.

### Importing

#### Import options:
- Loop Animation: set if the imported animation should loop
- Image Folder: set the folder to look for images. If empty, plugin will look for a folder named "images" in the same folder as the .mohoproj file.
- Mask Layer: set which 2D render layers should be applied in group masks (important if your project already uses Light2D).
- IK Preference: see the Using Skeleton2DIK section.
- Save Shapes as Curves: saves vector layer as Curve2D resources (meant for debugging).
- Verbose: if checked, prints to the console information for debugging.

#### Import limitations:
- This plugin works with three types of track:
	- value linear (from LINEAR, STEP, EASE, EASE_IN and EASE_OUT keyframes);
	- value cubic (from SMOOTH);
	- and bezier (from BEZIER).
- This means that tracks mixing keyframes from one and another type won't be imported properly. They will be treated as a value linear track.
- Bezier tracks gives the most accurate result.
- Smooth and Ease keyframes may need some tweaking after importing:
	- Smooth: cubic interpolation in Godot can give some inexpected results such as movement between keyframes of the same value.
	- Ease: Moho's ease seams to be more than just a simple ease. We're using some easing values that aproximate Moho's motion, but it's not precise.
- IK results may not be really precise in runtime. You should bake it into the animation.
- This plugin does not generate images from project data, you'll have to export each layer in the rest pose. Remember that Godot rasterizes svg imports.
- There is some estimation happening when calculating Sprite position in the scene - check MohoSprite script for more details. It should work, but, if some layer seems a little bit off, you may tweak offset values to correct this.
- SmartBone Actions will be imported as if bone angle interpolation is always linear.
- Scaling bones will affect its children.
- If you plan on flipping the animation, this will mess up bones with independent angle. To solve this, use the IK Bake Plugin; it will also bake independent angle Smart Bones.
- If your animation should run in a CanvasLayer different than default, you'll need to update Light2D range layer values so that masks do work properly.

## 🦴 Skeleton2DIK

Solves IK in Node2Ds using FABRIK. Not performatic or precise enough to be used in runtime.

#### IK preference:
- This IK can't handle angle constrains but you may set its "preference": it will make sure the chain never bends in the opposite direction.
- It's a simpler approach for correcting behavior such as legs and arms bending backwards, but may not work for every situation.

### How to bake IK
- Select any Skeleton2DIK of a imported scene; the IK Bake plugin will appear in the inspector.
	- If your scene have multiple IKs on it, click on Launch Helper; a helper will be instanciated and you'll bake all IK at once.
- Select your bake interval (that's the time interval between keyframes):
- Helper will free itself and the other Skeleton2DIKs from the scene after finishing baking the scene's only animation.
- Final animation can be really heavy, so we're saving them as .res to optimize its size.

## 🖇️ Scene Merger
- You may need to combine multiple imports into a single scene. Use SceneMerger.tscn for that.
	- In the inspector, set a list of scenes to be merged and the result scene name.
	- Run the scene (F6) and it will merge the scenes.
	- Result will be saved in the same folder as the first scene path given.
- It simply checks for every NodePath and duplicates from one to another if a node is not found.
	- It will not check for differences in properties, script, class... with one exception: the AnimationPlayer. If an AnimationPlayer is found in the same path as another, it will combine their animation list into the merged one.

## ⚠️ Troubleshooting
- .mohoproj importation must happen after all images are imported. Otherwise, it will generate a scene with empty sprites.
- There's an AnimationPlayer error `Failed setting key [...], Track'[path]:angle'. Check if property exists or the type of key is right for the property` on a merged scene:
	- Some bone in your skeleton is a SmartBone in an animation, but a Bone2D in another, and got imported as Bone2D.
	- Set SmartBone script in said bone and copy its properties from the animation where it's a SmartBone (independent angle, constrains, actions).
	- Look through its tracks in all animations: if "rotation" is animated, you should change it to "angle". Rewrite the track path and it should work.
- Since Godot's animation is by interpolation and not frame by frame, we treat the frame 1 as the very beggining of the animation. This could cause some distortion in the first interpolation.
	- This distortion is also influenced by the frame rate of the project.
	- If you have a SmartBone Action that's not properly working and it fits this description, add more keyframes to the Smart Bone and reimport the animation.