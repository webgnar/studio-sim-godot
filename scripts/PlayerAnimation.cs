using Godot;

public partial class PlayerAnimation : Node
{
    [Export] public AnimationPlayer AnimationPlayer { get; set; }
    
    [ExportGroup("Animation Speeds")]
    [Export] public float IdleSpeed { get; set; } = 1.0f;
    [Export] public float WalkSpeed { get; set; } = 1.5f;
    [Export] public float RunSpeed { get; set; } = 2.0f;
    
    private bool _isMoving = false;
    private bool _isSprinting = false;
    private bool _isJumping = false;
    
    public override void _Ready()
    {
        // Get reference to AnimationPlayer node
        AnimationPlayer = GetNode<AnimationPlayer>("AnimationPlayer");
        
        if (AnimationPlayer == null)
        {
            GD.PrintErr("AnimationPlayer not found! Please check scene structure.");
        }
        else
        {
            // List available animations for debugging
            var availableAnimations = AnimationPlayer.GetAnimationList();
            GD.Print($"Available animations: {string.Join(", ", availableAnimations)}");
        }
    }
    
    // Called by PlayerController to update animation state
    public void UpdateAnimationState(Vector3 velocity, bool isOnFloor, bool isSprinting)
    {
        if (AnimationPlayer == null) 
        {
            GD.PrintErr("AnimationPlayer is null!");
            return;
        }
        
        bool wasMoving = _isMoving;
        _isMoving = velocity.Length() > 0.1f;
        _isSprinting = isSprinting && _isMoving;
        
        // Handle jumping/falling
        if (!isOnFloor)
        {
            if (!_isJumping)
            {
                // Try jump animation, fall back to idle if not available
                if (!PlayAnimation("jump", IdleSpeed))
                {
                    PlayAnimation("idle", IdleSpeed);
                }
                _isJumping = true;
            }
        }
        else
        {
            _isJumping = false;
            
            // Handle ground movement animations
            if (_isMoving)
            {
                if (_isSprinting)
                {
                    PlayAnimation("run", RunSpeed); // Use "run" for sprinting with faster speed
                }
                else
                {
                    PlayAnimation("walk", WalkSpeed); // Use "walk" for normal movement with moderate speed
                }
            }
            else
            {
                PlayAnimation("idle", IdleSpeed);
            }
        }
    }
    
    private bool PlayAnimation(string animationName, float speed = 1.0f)
    {
        if (AnimationPlayer != null && AnimationPlayer.HasAnimation(animationName))
        {
            if (AnimationPlayer.CurrentAnimation != animationName)
            {
                AnimationPlayer.Play(animationName);
                GD.Print($"Successfully playing animation: {animationName} at speed {speed}x");
            }
            
            // Set the speed multiplier
            AnimationPlayer.SpeedScale = speed;
            return true;
        }
        else
        {
            GD.PrintErr($"Animation '{animationName}' not found or AnimationPlayer is null!");
            return false;
        }
    }
}
