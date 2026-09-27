package br.com.redeapoio.rede_apoio

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val canal = "rede_apoio/modo_discreto"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal).setMethodCallHandler { call, result ->
            when (call.method) {
                "ativo" -> result.success(modoDiscretoAtivo())
                "definir" -> {
                    val ativar = call.argument<Boolean>("ativo") ?: false
                    try {
                        definirModoDiscreto(ativar)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("falha", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Nome completo da classe (namespace do código, não o applicationId).
    private fun atalho(nome: String) =
        ComponentName(this, "${MainActivity::class.java.name.substringBeforeLast('.')}.$nome")

    private fun modoDiscretoAtivo(): Boolean =
        packageManager.getComponentEnabledSetting(atalho("AtalhoDiscreto")) ==
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED

    /**
     * Liga um atalho e desliga o outro. DONT_KILL_APP mantém o app aberto;
     * o launcher pode levar alguns segundos para mostrar o novo ícone.
     * O atalho novo é ligado antes de desligar o antigo, para nunca ficar
     * sem ícone na tela inicial.
     */
    private fun definirModoDiscreto(ativar: Boolean) {
        val ligar = if (ativar) "AtalhoDiscreto" else "AtalhoPadrao"
        val desligar = if (ativar) "AtalhoPadrao" else "AtalhoDiscreto"
        packageManager.setComponentEnabledSetting(
            atalho(ligar),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        packageManager.setComponentEnabledSetting(
            atalho(desligar),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
