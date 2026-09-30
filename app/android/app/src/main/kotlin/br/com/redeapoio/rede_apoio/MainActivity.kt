package br.com.redeapoio.rede_apoio

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val canal = "rede_apoio/modo_discreto"

    /** Atalhos declarados no AndroidManifest.xml (activity-alias). */
    private val atalhos = listOf(
        "AtalhoPadrao",
        "AtalhoDiscreto", // Anotações
        "AtalhoCalculadora",
        "AtalhoTreinos",
        "AtalhoReceitas",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Saída rápida: fecha o app e o tira da lista de apps recentes,
        // para a última tela não aparecer na miniatura.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rede_apoio/sistema").setMethodCallHandler { call, result ->
            if (call.method == "sair") {
                result.success(true)
                finishAndRemoveTask()
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal).setMethodCallHandler { call, result ->
            when (call.method) {
                "atual" -> result.success(atalhoAtivo())
                "definir" -> {
                    val alvo = call.argument<String>("atalho")
                    if (alvo == null || alvo !in atalhos) {
                        result.error("atalho_invalido", "Atalho desconhecido: $alvo", null)
                    } else {
                        try {
                            ativarAtalho(alvo)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("falha", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Nome completo da classe (namespace do código, não o applicationId).
    private fun componente(nome: String) =
        ComponentName(this, "${MainActivity::class.java.name.substringBeforeLast('.')}.$nome")

    private fun ligado(nome: String): Boolean {
        val estado = packageManager.getComponentEnabledSetting(componente(nome))
        // DEFAULT = o que está no manifest: só o AtalhoPadrao nasce ligado.
        return if (estado == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
            nome == "AtalhoPadrao"
        } else {
            estado == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }
    }

    private fun atalhoAtivo(): String = atalhos.firstOrNull { ligado(it) } ?: "AtalhoPadrao"

    /**
     * Liga o atalho escolhido e depois desliga os outros, para nunca ficar
     * sem ícone. DONT_KILL_APP mantém o app aberto; o launcher pode levar
     * alguns segundos para mostrar o novo ícone.
     */
    private fun ativarAtalho(alvo: String) {
        packageManager.setComponentEnabledSetting(
            componente(alvo),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (outro in atalhos) {
            if (outro == alvo) continue
            packageManager.setComponentEnabledSetting(
                componente(outro),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
