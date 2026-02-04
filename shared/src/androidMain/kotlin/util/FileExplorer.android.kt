package util

/**
 * No Android, não abrimos o explorador de arquivos diretamente
 */
actual fun openInExplorer(path: String) {
    // Android não suporta abrir explorador de arquivos diretamente
    // Pode ser implementado com Intent.ACTION_VIEW se necessário
    println("Abrir pasta não suportado no Android: $path")
}
