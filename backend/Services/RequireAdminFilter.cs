namespace study_spot_backend.Services;

// Gates the label-moderation endpoints. Structurally mirrors RequireRegisteredFilter -
// one boolean check, not a role/claims system. There is no admin UI; this is exercised
// via curl, either against a real account with is_admin hand-set, or locally against
// the dev-bypass identity (seeded as admin - see AppDbContext).
public class RequireAdminFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var currentUser = context.HttpContext.RequestServices.GetRequiredService<CurrentUser>();
        var user = await currentUser.GetAsync(context.HttpContext.RequestAborted);

        if (user is null || !user.IsAdmin)
        {
            return Results.Problem(
                title: "Admin access required",
                statusCode: StatusCodes.Status403Forbidden);
        }

        return await next(context);
    }
}
