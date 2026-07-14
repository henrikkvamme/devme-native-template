package dev.starter.app

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
  private val requestLocalNetworkPermission = registerForActivityResult(
    ActivityResultContracts.RequestPermission(),
  ) {
    showContent()
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()

    if (needsLocalNetworkPermission()) {
      requestLocalNetworkPermission.launch("android.permission.ACCESS_LOCAL_NETWORK")
    } else {
      showContent()
    }
  }

  private fun needsLocalNetworkPermission(): Boolean =
    BuildConfig.DEBUG &&
      Build.VERSION.SDK_INT >= 37 &&
      checkSelfPermission("android.permission.ACCESS_LOCAL_NETWORK") !=
      PackageManager.PERMISSION_GRANTED

  private fun showContent() {
    val backend = (application as StarterApplication).backend

    setContent {
      MaterialTheme {
        val homeViewModel: HomeViewModel = viewModel(
          factory = HomeViewModel.Factory(backend),
        )
        StarterRoot(homeViewModel)
      }
    }
  }
}

private enum class Tab(
  val label: String,
  val icon: ImageVector,
) {
  Home("Home", Icons.Default.Home),
  Activity("Activity", Icons.Default.Checklist),
  Settings("Settings", Icons.Default.Settings),
}

@Composable
private fun StarterRoot(homeViewModel: HomeViewModel) {
  var selectedTab by remember { mutableStateOf(Tab.Home) }

  Scaffold(
    bottomBar = {
      NavigationBar {
        Tab.entries.forEach { tab ->
          NavigationBarItem(
            selected = selectedTab == tab,
            onClick = { selectedTab = tab },
            icon = { Icon(tab.icon, contentDescription = tab.label) },
            label = { Text(tab.label) },
          )
        }
      }
    },
  ) { padding ->
    when (selectedTab) {
      Tab.Home -> HomeScreen(homeViewModel, padding)
      Tab.Activity -> PlaceholderScreen("Activity", padding)
      Tab.Settings -> PlaceholderScreen("Settings", padding)
    }
  }
}

@Composable
private fun HomeScreen(
  viewModel: HomeViewModel,
  padding: PaddingValues,
) {
  val state by viewModel.state.collectAsStateWithLifecycle()

  LazyColumn(
    modifier = Modifier
      .fillMaxSize()
      .padding(padding),
    contentPadding = PaddingValues(24.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    item {
      Text("Starter", style = MaterialTheme.typography.displaySmall)
      Spacer(Modifier.height(8.dp))
      ConnectionCard(state, viewModel::sendPing)
      Spacer(Modifier.height(24.dp))
      Text("Latest events", style = MaterialTheme.typography.titleLarge)
    }

    if (state.events.isEmpty()) {
      item {
        Text(
          "Send a ping to verify the reactive connection.",
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    } else {
      items(state.events, key = BootstrapEvent::id) { event ->
        Card(modifier = Modifier.fillMaxWidth()) {
          Column(modifier = Modifier.padding(16.dp)) {
            Text(event.message, style = MaterialTheme.typography.titleMedium)
            Text(
              event.client.replaceFirstChar(Char::uppercase),
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }
  }
}

@Composable
private fun ConnectionCard(
  state: HomeUiState,
  sendPing: () -> Unit,
) {
  Card(modifier = Modifier.fillMaxWidth()) {
    Column(
      modifier = Modifier.padding(16.dp),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
      ) {
        val icon = if (state.error == null) Icons.Default.CheckCircle else Icons.Default.Warning
        Icon(icon, contentDescription = null)
        Text(
          when {
            state.isConnecting -> "Connecting"
            state.isConnected -> "Connected to Convex"
            else -> "Connection failed"
          },
          style = MaterialTheme.typography.titleMedium,
        )
      }

      state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }

      Button(
        onClick = sendPing,
        enabled = !state.isSendingPing,
      ) {
        Icon(Icons.AutoMirrored.Filled.Send, contentDescription = null)
        Text("Send native ping", modifier = Modifier.padding(start = 8.dp))
      }
    }
  }
}

@Composable
private fun PlaceholderScreen(
  title: String,
  padding: PaddingValues,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(padding)
      .padding(24.dp),
  ) {
    Text(title, style = MaterialTheme.typography.displaySmall)
    Text("Replace this tab with your native feature.")
  }
}
