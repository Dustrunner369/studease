namespace study_spot_backend.Dtos;

// The client's boot call. IsGuest tells the Flutter app whether to show the Profile tab's
// "create an account" prompt; EntryCount drives the 3-spot guest-limit UI before the
// server even has to reject a write.
public record MeDto(Guid Id, string Handle, string DisplayName, bool IsGuest, int EntryCount, string? AvatarId);

// Completes registration - for a brand new identity, or a guest (IsGuest=true) upgrading
// in place. See CurrentUser and POST /me in Program.cs.
public record RegisterRequest(string Handle, string DisplayName);

// Sets the caller's preset profile icon. See AvatarIds for the fixed set of allowed values.
public record UpdateAvatarRequest(string AvatarId);
