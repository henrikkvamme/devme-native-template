package dev.starter.app

import android.content.Context
import dev.convex.android.ConvexClientWithAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed interface AuthenticationUiState {
  data object Restoring : AuthenticationUiState
  data object SignedOut : AuthenticationUiState
  data object SignedIn : AuthenticationUiState
  data class Failed(val message: String) : AuthenticationUiState
}

class AuthenticationController(
  private val client: ConvexClientWithAuth<BetterAuthSession>,
  private val provider: BetterAuthConvexProvider,
) {
  private val mutableState = MutableStateFlow<AuthenticationUiState>(AuthenticationUiState.Restoring)
  val state: StateFlow<AuthenticationUiState> = mutableState.asStateFlow()
  private var authenticatedSubject: String? = null

  suspend fun restore() {
    client.loginFromCache().fold(
      onSuccess = { session ->
        authenticatedSubject = session.subject
        mutableState.value = AuthenticationUiState.SignedIn
      },
      onFailure = {
        authenticatedSubject = null
        mutableState.value = AuthenticationUiState.SignedOut
      },
    )
  }

  suspend fun signIn(context: Context) {
    mutableState.value = AuthenticationUiState.Restoring
    client.login(context).fold(
      onSuccess = { session ->
        authenticatedSubject = session.subject
        mutableState.value = AuthenticationUiState.SignedIn
      },
      onFailure = { error ->
        mutableState.value = AuthenticationUiState.Failed(
          error.localizedMessage ?: "Google sign-in failed",
        )
      },
    )
  }

  suspend fun signOut(context: Context) {
    client.logout(context)
    authenticatedSubject = null
    mutableState.value = AuthenticationUiState.SignedOut
  }

  suspend fun deleteAccount(context: Context) {
    val expectedSubject = authenticatedSubject ?: run {
      mutableState.value = AuthenticationUiState.SignedOut
      return
    }
    val freshSession = runCatching { provider.reauthenticate(context) }.getOrElse { error ->
      mutableState.value = AuthenticationUiState.Failed(
        error.localizedMessage ?: "Account verification failed",
      )
      return
    }
    if (freshSession.subject != expectedSubject) {
      client.logout(context)
      authenticatedSubject = null
      mutableState.value = AuthenticationUiState.Failed(
        "Sign in with the same account that you are trying to delete.",
      )
      return
    }
    runCatching { provider.deleteUser(context, freshSession) }.fold(
      onSuccess = {
        client.logout(context)
        authenticatedSubject = null
        mutableState.value = AuthenticationUiState.SignedOut
      },
      onFailure = { error ->
        mutableState.value = AuthenticationUiState.Failed(
          error.localizedMessage ?: "Account deletion failed",
        )
      },
    )
  }
}
