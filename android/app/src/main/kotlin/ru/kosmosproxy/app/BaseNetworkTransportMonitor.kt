package ru.kosmosproxy.app

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest

/**
 * Caches the validated physical default network before the VPN overlay.
 *
 * Android switches [ConnectivityManager.activeNetwork] to the VPN after a
 * tunnel starts. During a mobile -> Wi-Fi handover that value therefore cannot
 * be used alone: inspect all validated, non-VPN transports and prefer the
 * validated Wi-Fi that Android has made available. This preserves cellular
 * when it is the only physical path, and prevents a stale cellular value from
 * keeping Wi-Fi-only bypass candidates alive.
 */
object BaseNetworkTransportMonitor {
    private const val NONE = "none"
    private const val OTHER = "other"
    private const val WIFI = "wifi"
    private const val CELLULAR = "cellular"

    @Volatile private var current: String = NONE

    fun start() {
        refreshFromPhysicalNetworks()
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        // Observe physical candidates directly; activeNetwork becomes the VPN
        // overlay once connected and must not hide a subsequent Wi-Fi handover.
        runCatching { Application.connectivity.registerNetworkCallback(request, callback) }
    }

    fun transport(): String {
        refreshFromPhysicalNetworks()
        return current
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = refreshFromPhysicalNetworks()
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = refreshFromPhysicalNetworks()
        override fun onLost(network: Network) = refreshFromPhysicalNetworks()
    }

    private fun refreshFromPhysicalNetworks() {
        val validated = Application.connectivity.allNetworks.mapNotNull { network ->
            val caps = Application.connectivity.getNetworkCapabilities(network) ?: return@mapNotNull null
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return@mapNotNull null
            caps
        }
        current = when {
            // A validated Wi-Fi is Android's preferred physical route when it
            // coexists with mobile data, including while the VPN is active.
            validated.any { it.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) } -> WIFI
            validated.any { it.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) } -> CELLULAR
            validated.isNotEmpty() -> OTHER
            else -> NONE
        }
    }
}
