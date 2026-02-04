package util

/**
 * No iOS, não abrimos o explorador de arquivos diretamente
 */
actual fun openInExplorer(path: String) {
    // iOS não suporta abrir explorador de arquivos diretamente
    println("Abrir pasta não suportado no iOS: $path")
}
