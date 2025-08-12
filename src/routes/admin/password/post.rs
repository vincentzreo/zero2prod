use actix_web::{error::InternalError, web, HttpResponse};
use actix_web_flash_messages::FlashMessage;
use secrecy::{ExposeSecret, SecretString};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    authentication::{validate_credentials, AuthError, Credentials},
    routes::admin::dashboard::get_username,
    session_state::TypedSession,
    utils::{e500, see_other},
};

#[derive(serde::Deserialize)]
pub struct FormData {
    pub current_password: SecretString,
    pub new_password: SecretString,
    pub new_password_check: SecretString,
}

pub async fn change_password(
    form: web::Form<FormData>,
    session: TypedSession,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, actix_web::Error> {
    // Handle password change logic here
    let user_id = reject_anonymous_users(session).await?;
    if form.new_password.expose_secret() != form.new_password_check.expose_secret() {
        FlashMessage::error("You entered two different new passwords the field values must match.")
            .send();
        return Ok(see_other("/admin/password"));
    }
    if form.new_password.expose_secret().len() < 12 {
        FlashMessage::error("New password must be at least 12 characters long.").send();
        return Ok(see_other("/admin/password"));
    }
    let username = get_username(user_id, &pool).await.map_err(e500)?;
    let credentials = Credentials {
        username,
        password: form.0.current_password,
    };
    if let Err(e) = validate_credentials(credentials, &pool).await {
        return match e {
            AuthError::InvalidCredentials(_) => {
                FlashMessage::error("The current password you provided is incorrect.").send();
                Ok(see_other("/admin/password"))
            }
            AuthError::UnexpectedError(_) => Err(e500(e)),
        };
    }
    crate::authentication::change_password(user_id, form.0.new_password, &pool)
        .await
        .map_err(e500)?;
    FlashMessage::success("Your password has been changed.").send();
    Ok(see_other("/admin/password"))
}

async fn reject_anonymous_users(session: TypedSession) -> Result<Uuid, actix_web::Error> {
    match session.get_user_id().map_err(e500)? {
        Some(id) => Ok(id),
        None => {
            let response = see_other("/login");
            let e = anyhow::anyhow!("The user has not logged in");
            Err(InternalError::from_response(e, response).into())
        }
    }
}
