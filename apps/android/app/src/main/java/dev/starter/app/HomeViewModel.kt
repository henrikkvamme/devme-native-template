package dev.starter.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class HomeUiState(
  val isConnected: Boolean = false,
  val isConnecting: Boolean = true,
  val isSendingPing: Boolean = false,
  val error: String? = null,
  val events: List<BootstrapEvent> = emptyList(),
)

class HomeViewModel(
  private val backend: StarterBackend,
) : ViewModel() {
  private val mutableState = MutableStateFlow(HomeUiState())
  val state: StateFlow<HomeUiState> = mutableState.asStateFlow()

  init {
    viewModelScope.launch {
      backend.bootstrapEvents().collect { result ->
        result.fold(
          onSuccess = { events ->
            mutableState.update {
              it.copy(
                isConnected = true,
                isConnecting = false,
                error = null,
                events = events,
              )
            }
          },
          onFailure = { error ->
            mutableState.update {
              it.copy(
                isConnected = false,
                isConnecting = false,
                error = error.localizedMessage,
              )
            }
          },
        )
      }
    }
  }

  fun sendPing() {
    if (state.value.isSendingPing) return

    viewModelScope.launch {
      mutableState.update { it.copy(isSendingPing = true) }
      runCatching { backend.ping() }
        .onFailure { error ->
          mutableState.update { it.copy(error = error.localizedMessage) }
        }
      mutableState.update { it.copy(isSendingPing = false) }
    }
  }

  class Factory(
    private val backend: StarterBackend,
  ) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
      HomeViewModel(backend) as T
  }
}
