package dev.starter.app

import android.content.Context
import android.content.Intent
import android.net.Uri
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

sealed interface BillingUiState {
  data object Unavailable : BillingUiState
  data object Loading : BillingUiState
  data object Free : BillingUiState
  data object Active : BillingUiState
  data class Failed(val message: String) : BillingUiState
}

class AuthenticationController(
  private val client: ConvexClientWithAuth<BetterAuthSession>,
  private val provider: BetterAuthConvexProvider,
) {
  private val mutableState = MutableStateFlow<AuthenticationUiState>(AuthenticationUiState.Restoring)
  val state: StateFlow<AuthenticationUiState> = mutableState.asStateFlow()
  private val mutableBilling = MutableStateFlow<BillingUiState>(BillingUiState.Unavailable)
  val billing: StateFlow<BillingUiState> = mutableBilling.asStateFlow()
  private val mutableAccountError = MutableStateFlow<String?>(null)
  val accountError: StateFlow<String?> = mutableAccountError.asStateFlow()
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
    if (mutableState.value == AuthenticationUiState.SignedIn) refreshBilling()
  }

  suspend fun signIn(context: Context) {
    mutableAccountError.value = null
    mutableState.value = AuthenticationUiState.Restoring
    client.login(context).fold(
      onSuccess = { session ->
        authenticatedSubject = session.subject
        mutableState.value = AuthenticationUiState.SignedIn
        refreshBilling()
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
    mutableState.value = AuthenticationUiState.SignedOut
    mutableBilling.value = BillingUiState.Unavailable
    mutableAccountError.value = null
    authenticatedSubject = null
  }

  suspend fun deleteAccount(context: Context) {
    val expectedSubject = authenticatedSubject ?: run {
      mutableState.value = AuthenticationUiState.SignedOut
      return
    }
    val freshSession = runCatching { provider.reauthenticate(context) }.getOrElse { error ->
      mutableAccountError.value = error.localizedMessage ?: "Account verification failed"
      return
    }
    if (freshSession.subject != expectedSubject) {
      client.logout(context)
      authenticatedSubject = null
      mutableBilling.value = BillingUiState.Unavailable
      mutableState.value = AuthenticationUiState.Failed(
        "Sign in with the same account that you are trying to delete.",
      )
      return
    }
    runCatching { provider.deleteUser(context, freshSession) }.fold(
      onSuccess = {
        client.logout(context)
        mutableState.value = AuthenticationUiState.SignedOut
        mutableBilling.value = BillingUiState.Unavailable
        mutableAccountError.value = null
        authenticatedSubject = null
      },
      onFailure = { error ->
        mutableState.value = AuthenticationUiState.SignedIn
        mutableAccountError.value = error.localizedMessage ?: "Account deletion failed"
        refreshBilling()
      },
    )
  }

  suspend fun refreshBilling() {
    if (mutableState.value != AuthenticationUiState.SignedIn) {
      mutableBilling.value = BillingUiState.Unavailable
      return
    }
    mutableBilling.value = BillingUiState.Loading
    runCatching { provider.subscriptions() }.fold(
      onSuccess = { subscriptions ->
        mutableBilling.value = if (subscriptions.any(BetterAuthSubscription::isActive)) {
          BillingUiState.Active
        } else {
          BillingUiState.Free
        }
      },
      onFailure = { error ->
        mutableBilling.value = BillingUiState.Failed(
          error.localizedMessage ?: "Subscription could not be loaded",
        )
      },
    )
  }

  suspend fun startCheckout(context: Context) {
    openUrl(context, runCatching { provider.subscriptionCheckoutUrl() })
  }

  suspend fun manageSubscription(context: Context) {
    openUrl(context, runCatching { provider.billingPortalUrl() })
  }

  private fun openUrl(context: Context, result: Result<String>) {
    result.fold(
      onSuccess = { url ->
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
      },
      onFailure = { error ->
        mutableBilling.value = BillingUiState.Failed(
          error.localizedMessage ?: "Billing could not be opened",
        )
      },
    )
  }
}
