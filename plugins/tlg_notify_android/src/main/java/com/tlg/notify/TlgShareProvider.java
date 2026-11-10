package com.tlg.notify;

import androidx.core.content.FileProvider;

/**
 * FileProvider khusus plugin: Godot sudah mendaftarkan androidx FileProvider sendiri,
 * dan manifest tidak boleh memuat kelas provider yang sama dua kali.
 */
public class TlgShareProvider extends FileProvider {
}
