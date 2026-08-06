namespace study_spot_backend.Services;

// Guards every endpoint that touches a user's own data. Guests pass through untouched -
// CurrentUser.GetAsync auto-provisions them - so this only ever actually blocks a real,
// non-anonymous identity that has a valid token but hasn't called POST /me yet.
public class RequireRegisteredFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var currentUser = context.HttpContext.RequestServices.GetRequiredService<CurrentUser>();
        var user = await currentUser.GetAsync(context.HttpContext.RequestAborted);

        if (user is null)
        {
            return Results.Problem(
                type: "https://studease.app/problems/registration-required",
                title: "Registration required",
                detail: "This identity is authenticated but has not completed registration. POST /me first.",
                statusCode: StatusCodes.Status403Forbidden);
        }

        return await next(context);
    }
}
