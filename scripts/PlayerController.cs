using Godot;

public partial class PlayerController : CharacterBody3D
{
    // --- EXPORTED VARIABLES ---
    // These values will be editable in the Godot Inspector.

    [ExportGroup("Movement Stats")]
    [Export] public float WalkSpeed { get; set; } = 5.0f;
    [Export] public float SprintSpeed { get; set; } = 8.0f;
    [Export] public float JumpVelocity { get; set; } = 4.5f;
    [Export] public float Gravity { get; set; } = 9.8f;
    [Export] public float AirControl { get; set; } = 2.0f;
    [Export] public float Inertia { get; set; } = 10.0f;

    [ExportGroup("Camera Stats")]
    [Export] public float Sensitivity { get; set; } = 0.003f;

    [ExportGroup("Head Bob")]
    [Export] public float BobFrequency { get; set; } = 2.0f;
    [Export] public float BobAmplitude { get; set; } = 0.3f;

    [ExportGroup("FOV Settings")]
    [Export] public float BaseFov { get; set; } = 75.0f;
    [Export] public float MaxFovIncrease { get; set; } = 15.0f;
    [Export] public float FovTransitionSpeed { get; set; } = 2.0f;

    // --- PRIVATE VARIABLES ---

    // We get a reference to the camera in _Ready().
    private Camera3D _camera;
    
    // Animation controller reference
    private PlayerAnimation _playerAnimation;
    
    // Head bob variables
    private float _bobTime = 0.0f;
    private Vector3 _originalCameraPosition;
    
    // FOV variables
    private float _currentFov;
    
    // Current speed property - returns walk or sprint speed based on Shift key
    private float CurrentSpeed => Input.IsKeyPressed(Key.Shift) ? SprintSpeed : WalkSpeed;
    
    // --- GODOT METHODS ---

    public override void _Ready()
    {
        // Get a reference to the Camera3D node.
        // Try multiple possible paths for the camera
        if (HasNode("Head/Camera3D"))
        {
            _camera = GetNode<Camera3D>("Head/Camera3D");
        }
        else if (HasNode("Head/Camera"))
        {
            _camera = GetNode<Camera3D>("Head/Camera");
        }
        else if (HasNode("Camera3D"))
        {
            _camera = GetNode<Camera3D>("Camera3D");
        }
        else if (HasNode("Camera"))
        {
            _camera = GetNode<Camera3D>("Camera");
        }
        else
        {
            GD.PrintErr("Camera not found! Please check scene structure.");
            return;
        }

        // Capture the mouse when the game starts.
        // This hides the cursor and keeps it centered.
        Input.MouseMode = Input.MouseModeEnum.Captured;
        GD.Print("Mouse captured, camera found at: " + _camera.GetPath());
        
        // Store the original camera position for head bob calculations
        _originalCameraPosition = _camera.Position;
        
        // Initialize FOV
        _camera.Fov = BaseFov;
        _currentFov = BaseFov;
        
        // Get reference to animation controller (try common paths)
        if (HasNode("Model/PlayerAnimation"))
        {
            _playerAnimation = GetNode<PlayerAnimation>("Model/PlayerAnimation");
            GD.Print("Found PlayerAnimation at: Model/PlayerAnimation");
        }
        else if (HasNode("PlayerAnimation"))
        {
            _playerAnimation = GetNode<PlayerAnimation>("PlayerAnimation");
            GD.Print("Found PlayerAnimation at: PlayerAnimation");
        }
        else if (HasNode("human"))
        {
            _playerAnimation = GetNode<PlayerAnimation>("human");
            GD.Print("Found PlayerAnimation at: human");
        }
        else if (HasNode("AnimationController"))
        {
            _playerAnimation = GetNode<PlayerAnimation>("AnimationController");
            GD.Print("Found PlayerAnimation at: AnimationController");
        }
        
        if (_playerAnimation == null)
        {
            GD.PrintErr("PlayerAnimation script not found - animations will be skipped");
            GD.Print("Available child nodes:");
            foreach (Node child in GetChildren())
            {
                GD.Print($"  - {child.Name} ({child.GetType().Name})");
            }
        }
        else
        {
            GD.Print("PlayerAnimation script found and connected!");
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        // --- GRAVITY ---
        // Add gravity. If the character is on the floor, we don't apply gravity.
        if (!IsOnFloor())
        {
            Velocity = new Vector3(Velocity.X, Velocity.Y - (Gravity * (float)delta), Velocity.Z);
        }

        // --- JUMPING ---
        // Handle the jump action.
        if (Input.IsActionJustPressed("jump") && IsOnFloor())
        {
            Velocity = new Vector3(Velocity.X, JumpVelocity, Velocity.Z);
        }

        // --- MOVEMENT ---
        // Get the input direction vector from the input actions.
        Vector2 inputDir = Input.GetVector("move_left", "move_right", "move_forward", "move_back");
        
        // Convert the 2D input vector to a 3D direction vector.
        Vector3 direction = (Transform.Basis * new Vector3(inputDir.X, 0, inputDir.Y)).Normalized();
        
        if (IsOnFloor())
        {
            // Full control when on the ground
            if (direction != Vector3.Zero)
            {
                Velocity = new Vector3(direction.X * CurrentSpeed, Velocity.Y, direction.Z * CurrentSpeed);
            }
            else
            {
                // If no input, apply inertia-based friction to stop the character smoothly.
                Vector3 horizontalVelocity = new Vector3(Velocity.X, 0, Velocity.Z);
                horizontalVelocity = horizontalVelocity.Lerp(Vector3.Zero, Inertia * (float)delta);
                Velocity = new Vector3(horizontalVelocity.X, Velocity.Y, horizontalVelocity.Z);
            }
        }
        else
        {
            // Limited air control - lerp velocity towards input direction
            if (direction != Vector3.Zero)
            {
                Vector3 targetVelocity = new Vector3(direction.X * CurrentSpeed, Velocity.Y, direction.Z * CurrentSpeed);
                Vector3 currentHorizontal = new Vector3(Velocity.X, 0, Velocity.Z);
                Vector3 targetHorizontal = new Vector3(targetVelocity.X, 0, targetVelocity.Z);
                
                // Lerp horizontal velocity towards target with limited air control
                Vector3 newHorizontal = currentHorizontal.Lerp(targetHorizontal, AirControl * (float)delta * 3.0f);
                Velocity = new Vector3(newHorizontal.X, Velocity.Y, newHorizontal.Z);
            }
        }

        // --- DYNAMIC FOV ---
        // Adjust FOV based on movement speed for sense of speed
        float speedRatio = Velocity.Length() / SprintSpeed;  // Use sprint speed as max reference
        float targetFov = BaseFov + (speedRatio * MaxFovIncrease);
        
        // Clamp the FOV to prevent it from getting too crazy
        targetFov = Mathf.Clamp(targetFov, BaseFov, BaseFov + MaxFovIncrease);
        
        // Smoothly transition to target FOV
        _currentFov = Mathf.Lerp(_currentFov, targetFov, FovTransitionSpeed * (float)delta);
        _camera.Fov = _currentFov;

        // --- HEAD BOB ---
        // Apply head bob when moving and on the ground
        if (IsOnFloor() && Velocity.Length() > 0.1f)
        {
            // Calculate speed factor (how fast we're moving relative to max speed)
            float speedFactor = Velocity.Length() / CurrentSpeed;
            
            // Calculate dynamic frequency - faster when sprinting
            float currentFrequency = BobFrequency * (CurrentSpeed / WalkSpeed);
            
            // Increment bob time based on movement speed and dynamic frequency
            _bobTime += (float)delta * currentFrequency * speedFactor;
            
            // Calculate vertical bob using sine wave (amplitude scales with speed)
            float bobY = Mathf.Sin(_bobTime) * BobAmplitude * speedFactor;
            
            // Calculate horizontal bob synchronized with vertical - side sway happens every other step
            float bobX = Mathf.Sin(_bobTime * 0.5f) * BobAmplitude * 0.3f * speedFactor;
            
            // Apply the bob to the camera position
            _camera.Position = _originalCameraPosition + new Vector3(bobX, bobY, 0);
        }
        else
        {
            // When not moving, smoothly return camera to original position
            _camera.Position = _camera.Position.Lerp(_originalCameraPosition, 5.0f * (float)delta);
            
            // Reset bob time when not moving
            if (Velocity.Length() < 0.1f)
            {
                _bobTime = 0.0f;
            }
        }

        // --- APPLY MOVEMENT ---
        // This is the core function of CharacterBody3D. It moves the character and handles collisions.
        MoveAndSlide();
        
        // --- UPDATE ANIMATIONS ---
        // Send movement data to animation controller
        if (_playerAnimation != null)
        {
            bool isSprinting = Input.IsKeyPressed(Key.Shift);
            _playerAnimation.UpdateAnimationState(Velocity, IsOnFloor(), isSprinting);
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        // --- MOUSE LOOK ---
        // This function handles mouse rotation for the camera.
        if (@event is InputEventMouseMotion mouseMotion && _camera != null)
        {
            // Only process mouse look if mouse is captured
            if (Input.MouseMode == Input.MouseModeEnum.Captured)
            {
                // Rotate the player horizontally (Yaw).
                // We rotate the entire CharacterBody3D node.
                RotateY(-mouseMotion.Relative.X * Sensitivity);

                // Rotate the camera vertically (Pitch).
                // We rotate the Camera3D node itself.
                _camera.RotateX(-mouseMotion.Relative.Y * Sensitivity);

                // Clamp the vertical rotation to prevent the camera from flipping over.
                // Mathf.DegToRad converts degrees to radians.
                Vector3 rotation = _camera.Rotation;
                rotation.X = Mathf.Clamp(rotation.X, Mathf.DegToRad(-80f), Mathf.DegToRad(80f));
                _camera.Rotation = rotation;
            }
        }

        // You can also handle other inputs here, like pausing the game.
        if (Input.IsActionJustPressed("ui_cancel")) // ESC key
        {
            // Toggle mouse capture
            if (Input.MouseMode == Input.MouseModeEnum.Captured)
            {
                Input.MouseMode = Input.MouseModeEnum.Visible;
                GD.Print("Mouse released");
            }
            else
            {
                Input.MouseMode = Input.MouseModeEnum.Captured;
                GD.Print("Mouse captured");
            }
        }
    }

    public override void _ExitTree()
    {
        // Make sure to release the mouse when the player object is removed.
        // This is good practice for when changing scenes or quitting the game.
        Input.MouseMode = Input.MouseModeEnum.Visible;
    }
}
