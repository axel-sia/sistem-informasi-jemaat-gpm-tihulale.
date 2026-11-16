-- =====================================================================
--  DATABASE PORTAL JEMAAT GEREJA BETH EDEN - GPM TIHULALE
--  Target : MySQL 8.0+ (juga kompatibel dengan MariaDB 10.5+)
--  Dibuat dari struktur data aplikasi (script.js) yang saat ini
--  tersimpan di localStorage browser (kunci "gpm_*").
--
--  Cara pakai:
--    mysql -u root -p < gpm_tihulale.sql
--  atau di phpMyAdmin: menu Import -> pilih berkas ini.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS gpm_tihulale
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gpm_tihulale;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 1. MASTER
-- ---------------------------------------------------------------------
CREATE TABLE sektor (
  id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama  VARCHAR(40) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sektor_nama (nama)
) ENGINE=InnoDB;

-- Berkas (PDF buletin/surat, foto, bukti transfer). Maks. 2 MB per berkas.
-- Alternatif: simpan berkas di folder server dan isi kolom `path` saja.
CREATE TABLE berkas (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama_asli   VARCHAR(255) NOT NULL,
  mime        VARCHAR(100) NOT NULL,
  ukuran      INT UNSIGNED NOT NULL DEFAULT 0,
  path        VARCHAR(500) NULL,
  isi         MEDIUMBLOB NULL,
  dibuat_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE pengaturan (
  kunci  VARCHAR(80) NOT NULL,
  nilai  TEXT NULL,
  PRIMARY KEY (kunci)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. AKUN PENGGUNA
-- ---------------------------------------------------------------------
-- password_hash: isi dengan hash dari aplikasi server (bcrypt/argon2),
-- jangan pernah menyimpan password asli. Aturan "Admin Sektor wajib punya sektor"
-- ditegakkan di aplikasi (CHECK tidak boleh memakai kolom FK ber-aksi SET NULL).
CREATE TABLE users (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama               VARCHAR(120) NOT NULL,
  username           VARCHAR(20)  NOT NULL,
  email              VARCHAR(150) NOT NULL,
  role               ENUM('admin','ketua','sekretaris','bendahara','adminsektor') NOT NULL,
  sektor_id          TINYINT UNSIGNED NULL,
  status             ENUM('menunggu','aktif','nonaktif') NOT NULL DEFAULT 'menunggu',
  akses_keuangan     TINYINT(1) NOT NULL DEFAULT 0,
  password_hash      VARCHAR(255) NOT NULL,
  pertanyaan_keamanan VARCHAR(200) NULL,
  jawaban_hash       VARCHAR(255) NULL,
  login_terakhir     DATETIME NULL,
  dibuat_pada        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role (role),
  CONSTRAINT fk_users_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. DATA WARGA & REGISTRASI
-- ---------------------------------------------------------------------
CREATE TABLE warga (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama             VARCHAR(150) NOT NULL,
  sektor_id        TINYINT UNSIGNED NOT NULL,
  kategori         ENUM('Kepala Keluarga','Istri','Janda','Duda','Pemuda','Anak') NOT NULL,
  jenis_kelamin    ENUM('Laki-laki','Perempuan') NULL,
  status           ENUM('Aktif','Pindah','Meninggal') NOT NULL DEFAULT 'Aktif',
  tgl_lahir        DATE NULL,
  telp             VARCHAR(30) NULL,
  alamat           TEXT NULL,
  -- persetujuan Admin Utama untuk data yang diinput Admin Sektor
  persetujuan      ENUM('Disetujui','Menunggu','Ditolak') NOT NULL DEFAULT 'Disetujui',
  diinput_oleh     INT UNSIGNED NULL,
  disetujui_oleh   INT UNSIGNED NULL,
  -- pengajuan pindah sektor
  pindah_ke_sektor_id TINYINT UNSIGNED NULL,
  pindah_status    ENUM('Menunggu','Disetujui','Ditolak') NULL,
  dibuat_pada      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diubah_pada      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_warga_sektor (sektor_id),
  KEY idx_warga_status (status, persetujuan),
  KEY idx_warga_nama (nama),
  CONSTRAINT fk_warga_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_warga_pindah FOREIGN KEY (pindah_ke_sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_warga_input  FOREIGN KEY (diinput_oleh) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_warga_setuju FOREIGN KEY (disetujui_oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE mutasi_jemaat (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal     DATE NOT NULL,
  nama        VARCHAR(150) NOT NULL,
  jenis       ENUM('Pindah Masuk','Pindah Keluar') NOT NULL,
  sektor_id   TINYINT UNSIGNED NULL,
  asal_tujuan VARCHAR(150) NULL,
  alasan      VARCHAR(255) NULL,
  warga_id    INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_mutasi_tanggal (tanggal),
  CONSTRAINT fk_mutasi_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_mutasi_warga  FOREIGN KEY (warga_id) REFERENCES warga(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Buku Register Besar. Kolom khusus tiap jenis (ayah, ibu, pasangan, dll.)
-- disimpan di `detail` (JSON) karena berbeda per jenis register.
CREATE TABLE register_besar (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  jenis       ENUM('Baptis','Sidi','Nikah','Kematian') NOT NULL,
  urut        INT UNSIGNED NOT NULL,
  no_register VARCHAR(30) NOT NULL,
  nama        VARCHAR(150) NOT NULL,
  tgl_lahir   DATE NULL,
  tanggal     DATE NULL,
  tempat      VARCHAR(150) NULL,
  pelayan     VARCHAR(150) NULL,
  detail      JSON NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_register (jenis, urut),
  KEY idx_register_tanggal (tanggal)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. SURAT & SURAT KEPUTUSAN
-- ---------------------------------------------------------------------
CREATE TABLE surat (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nomor         VARCHAR(80) NOT NULL,
  tanggal       DATE NOT NULL,
  jenis         ENUM('Surat Masuk','Surat Keluar') NOT NULL,
  pihak         VARCHAR(200) NULL COMMENT 'Pengirim / tujuan',
  diterima      VARCHAR(150) NULL,
  kategori      VARCHAR(60) NULL,
  perihal       VARCHAR(255) NULL,
  keterangan    TEXT NULL,
  berkas_id     INT UNSIGNED NULL,
  persetujuan   ENUM('Menunggu','Disetujui','Ditolak') NOT NULL DEFAULT 'Menunggu',
  disetujui_oleh INT UNSIGNED NULL,
  dibuat_oleh   INT UNSIGNED NULL,
  dibuat_pada   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_surat_nomor (nomor),
  KEY idx_surat_tanggal (tanggal),
  CONSTRAINT fk_surat_berkas FOREIGN KEY (berkas_id) REFERENCES berkas(id) ON DELETE SET NULL,
  CONSTRAINT fk_surat_setuju FOREIGN KEY (disetujui_oleh) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_surat_oleh   FOREIGN KEY (dibuat_oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE disposisi_surat (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  surat_id   INT UNSIGNED NOT NULL,
  tujuan     VARCHAR(100) NOT NULL COMMENT 'mis. Sekretaris, Bendahara, seksi, sektor',
  instruksi  TEXT NULL,
  tanggal    DATE NOT NULL,
  oleh       INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_disposisi_surat (surat_id),
  CONSTRAINT fk_disp_surat FOREIGN KEY (surat_id) REFERENCES surat(id) ON DELETE CASCADE,
  CONSTRAINT fk_disp_oleh  FOREIGN KEY (oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE surat_keputusan (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nomor       VARCHAR(80) NOT NULL,
  urut        INT UNSIGNED NULL,
  jenis       VARCHAR(60) NOT NULL COMMENT 'mis. Pengangkatan Panitia',
  nama        VARCHAR(200) NOT NULL,
  menimbang   TEXT NULL,
  mengingat   TEXT NULL,
  masa        VARCHAR(120) NULL,
  tanggal     DATE NOT NULL,
  tempat      VARCHAR(100) NULL,
  sekretaris  VARCHAR(120) NULL,
  status      ENUM('Diterbitkan','Menunggu','Disahkan','Ditolak') NOT NULL DEFAULT 'Diterbitkan',
  dibuat_oleh INT UNSIGNED NULL,
  tgl_terbit  DATE NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sk_nomor (nomor),
  CONSTRAINT fk_sk_oleh FOREIGN KEY (dibuat_oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE sk_anggota (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sk_id     INT UNSIGNED NOT NULL,
  urut      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  jabatan   VARCHAR(100) NOT NULL,
  nama      VARCHAR(150) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_sk_anggota (sk_id),
  CONSTRAINT fk_ska_sk FOREIGN KEY (sk_id) REFERENCES surat_keputusan(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. NOTULEN, PELKES, IBADAH
-- ---------------------------------------------------------------------
CREATE TABLE notulen (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  jenis     VARCHAR(60) NOT NULL,
  judul     VARCHAR(200) NOT NULL,
  tanggal   DATE NOT NULL,
  tempat    VARCHAR(150) NULL,
  pimpinan  VARCHAR(120) NULL,
  notulis   VARCHAR(120) NULL,
  peserta   TEXT NULL,
  agenda    TEXT NULL,
  isi       LONGTEXT NULL,
  dibuat_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notulen_tanggal (tanggal)
) ENGINE=InnoDB;

CREATE TABLE notulen_keputusan (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  notulen_id  INT UNSIGNED NOT NULL,
  teks        TEXT NOT NULL,
  pj          VARCHAR(120) NULL COMMENT 'Penanggung jawab',
  target      DATE NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'Belum',
  PRIMARY KEY (id),
  KEY idx_nk_notulen (notulen_id),
  CONSTRAINT fk_nk_notulen FOREIGN KEY (notulen_id) REFERENCES notulen(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE program_pelkes (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tahun     YEAR NOT NULL,
  unit      VARCHAR(100) NOT NULL,
  nama      VARCHAR(200) NOT NULL,
  target    VARCHAR(255) NULL,
  capaian   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  status    VARCHAR(30) NULL,
  anggaran  DECIMAL(15,2) NOT NULL DEFAULT 0,
  hasil     TEXT NULL,
  PRIMARY KEY (id),
  KEY idx_pelkes_tahun (tahun),
  CONSTRAINT ck_pelkes_capaian CHECK (capaian BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE jadwal_ibadah (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal     DATE NOT NULL,
  jam         TIME NULL,
  tempat      VARCHAR(150) NOT NULL,
  jenis       VARCHAR(60) NOT NULL COMMENT 'Tunas, Angkatan Muda, Sektor, Unit, dll.',
  unit        VARCHAR(100) NULL,
  tema        VARCHAR(255) NULL,
  pelayan     VARCHAR(150) NULL,
  PRIMARY KEY (id),
  KEY idx_ibadah_tanggal (tanggal),
  KEY idx_ibadah_jenis (jenis)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. KONTEN BERANDA PUBLIK
-- ---------------------------------------------------------------------
CREATE TABLE agenda (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  judul      VARCHAR(200) NOT NULL,
  kategori   VARCHAR(40) NOT NULL,
  waktu      VARCHAR(120) NULL COMMENT 'Teks bebas, mis. Minggu, 22 Nov 2026 - 09.00 WIT',
  deskripsi  TEXT NULL,
  foto_id    INT UNSIGNED NULL,
  dibuat_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_agenda_foto FOREIGN KEY (foto_id) REFERENCES berkas(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE agenda_sektor (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sektor_id   TINYINT UNSIGNED NOT NULL,
  judul       VARCHAR(200) NOT NULL,
  kategori    VARCHAR(40) NOT NULL,
  waktu       VARCHAR(120) NULL,
  deskripsi   TEXT NULL,
  foto_id     INT UNSIGNED NULL,
  tayang      TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Diajukan tampil di beranda publik',
  publikasi   ENUM('Menunggu','Disetujui','Ditolak') NOT NULL DEFAULT 'Menunggu',
  oleh        INT UNSIGNED NULL,
  dibuat      DATE NULL,
  PRIMARY KEY (id),
  KEY idx_as_sektor (sektor_id),
  KEY idx_as_publik (tayang, publikasi),
  CONSTRAINT fk_as_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_as_foto   FOREIGN KEY (foto_id) REFERENCES berkas(id) ON DELETE SET NULL,
  CONSTRAINT fk_as_oleh   FOREIGN KEY (oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE renungan (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal   DATE NOT NULL,
  judul     VARCHAR(200) NOT NULL,
  ayat      VARCHAR(100) NULL,
  teks      TEXT NULL COMMENT 'Isi ayat',
  isi       LONGTEXT NULL,
  doa       TEXT NULL,
  penulis   VARCHAR(120) NULL,
  PRIMARY KEY (id),
  KEY idx_renungan_tanggal (tanggal)
) ENGINE=InnoDB;

CREATE TABLE buletin (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal   DATE NOT NULL,
  judul     VARCHAR(150) NOT NULL COMMENT 'Edisi / periode',
  deskripsi TEXT NULL,
  status    ENUM('Terbit','Draf') NOT NULL DEFAULT 'Draf',
  berkas_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY idx_buletin_status (status, tanggal),
  CONSTRAINT fk_buletin_berkas FOREIGN KEY (berkas_id) REFERENCES berkas(id)
) ENGINE=InnoDB;

CREATE TABLE rekening_pembangunan (
  id          TINYINT UNSIGNED NOT NULL DEFAULT 1,
  bank        VARCHAR(100) NOT NULL,
  no_rekening VARCHAR(40) NOT NULL,
  atas_nama   VARCHAR(150) NOT NULL,
  diubah_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT ck_rekening_tunggal CHECK (id = 1)
) ENGINE=InnoDB;

CREATE TABLE foto_pembangunan (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  berkas_id  INT UNSIGNED NOT NULL,
  keterangan VARCHAR(255) NULL,
  dibuat_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_fp_berkas FOREIGN KEY (berkas_id) REFERENCES berkas(id)
) ENGINE=InnoDB;

CREATE TABLE foto_beranda (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  berkas_id  INT UNSIGNED NOT NULL,
  keterangan VARCHAR(255) NULL,
  dibuat_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_fb_berkas FOREIGN KEY (berkas_id) REFERENCES berkas(id)
) ENGINE=InnoDB;

CREATE TABLE panitia_pembangunan (
  id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  jabatan  VARCHAR(100) NOT NULL,
  nama     VARCHAR(150) NOT NULL,
  urut     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. KEUANGAN
-- ---------------------------------------------------------------------
CREATE TABLE penerimaan (
  id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal  DATE NOT NULL,
  uraian   VARCHAR(255) NOT NULL,
  metode   VARCHAR(40) NOT NULL DEFAULT 'Tunai',
  jumlah   DECIMAL(15,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_penerimaan_tanggal (tanggal),
  CONSTRAINT ck_penerimaan_jumlah CHECK (jumlah >= 0)
) ENGINE=InnoDB;

CREATE TABLE persepuluhan (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal   DATE NOT NULL,
  sektor_id TINYINT UNSIGNED NULL,
  jumlah    DECIMAL(15,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_persepuluhan_tanggal (tanggal),
  CONSTRAINT fk_pp_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT ck_pp_jumlah CHECK (jumlah >= 0)
) ENGINE=InnoDB;

CREATE TABLE pagu_apbj (
  tahun   YEAR NOT NULL,
  seksi   VARCHAR(80) NOT NULL,
  jumlah  DECIMAL(15,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (tahun, seksi)
) ENGINE=InnoDB;

CREATE TABLE disposisi_dana (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal     DATE NOT NULL,
  seksi       VARCHAR(80) NOT NULL,
  kegiatan    VARCHAR(255) NOT NULL,
  pengaju     VARCHAR(120) NULL,
  jumlah      DECIMAL(15,2) NOT NULL,
  status      ENUM('Menunggu','Disetujui','Ditolak','Dicairkan') NOT NULL DEFAULT 'Menunggu',
  disetujui_oleh INT UNSIGNED NULL,
  tgl_cair    DATE NULL,
  PRIMARY KEY (id),
  KEY idx_dd_status (status),
  CONSTRAINT fk_dd_setuju FOREIGN KEY (disetujui_oleh) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT ck_dd_jumlah CHECK (jumlah >= 0)
) ENGINE=InnoDB;

CREATE TABLE pengeluaran (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal       DATE NOT NULL,
  seksi         VARCHAR(80) NOT NULL COMMENT 'Pos anggaran (PTPU, PIPK, POS, PKK, ...)',
  kategori      VARCHAR(80) NOT NULL COMMENT 'Jenis belanja',
  uraian        VARCHAR(255) NOT NULL,
  jumlah        DECIMAL(15,2) NOT NULL,
  disposisi_id  INT UNSIGNED NULL COMMENT 'Terisi bila berasal dari pencairan dana',
  PRIMARY KEY (id),
  KEY idx_pengeluaran_tanggal (tanggal),
  KEY idx_pengeluaran_seksi (seksi, tanggal),
  CONSTRAINT fk_peng_disp FOREIGN KEY (disposisi_id) REFERENCES disposisi_dana(id) ON DELETE SET NULL,
  CONSTRAINT ck_peng_jumlah CHECK (jumlah >= 0)
) ENGINE=InnoDB;

CREATE TABLE setoran_sentralisasi (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal   DATE NOT NULL,
  periode   VARCHAR(40) NOT NULL,
  bank      VARCHAR(120) NOT NULL DEFAULT 'Rekening Sinode GPM',
  jumlah    DECIMAL(15,2) NOT NULL,
  bukti_id  INT UNSIGNED NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_ss_bukti FOREIGN KEY (bukti_id) REFERENCES berkas(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE dana_darurat (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal   DATE NOT NULL,
  jenis     VARCHAR(80) NOT NULL,
  penerima  VARCHAR(200) NOT NULL,
  jumlah    DECIMAL(15,2) NOT NULL,
  keterangan TEXT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Ringkasan saldo yang diterbitkan Bendahara ke beranda publik.
CREATE TABLE saldo_terbit (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tipe            ENUM('Minggu','Bulan','Tahun') NOT NULL,
  periode_awal    DATE NOT NULL,
  periode_akhir   DATE NOT NULL,
  saldo_masuk     DECIMAL(15,2) NOT NULL DEFAULT 0,
  saldo_keluar    DECIMAL(15,2) NOT NULL DEFAULT 0,
  saldo_kas_akhir DECIMAL(15,2) NOT NULL DEFAULT 0,
  diterbitkan_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  diterbitkan_oleh INT UNSIGNED NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_saldo_periode (tipe, periode_awal, periode_akhir),
  CONSTRAINT fk_st_oleh FOREIGN KEY (diterbitkan_oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. LAPORAN SEKTOR, RADAR & PASTORAL, AUDIT
-- ---------------------------------------------------------------------
CREATE TABLE jurnal_sektor (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sektor_id TINYINT UNSIGNED NOT NULL,
  tanggal   DATE NOT NULL,
  aksi      VARCHAR(40) NOT NULL COMMENT 'Baru, Ubah, Pindah, dll.',
  nama      VARCHAR(150) NOT NULL,
  lapor     TINYINT(1) NOT NULL DEFAULT 0,
  lawan     VARCHAR(100) NULL,
  warga_id  INT UNSIGNED NULL,
  oleh      INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_js_sektor (sektor_id, lapor),
  CONSTRAINT fk_js_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_js_warga  FOREIGN KEY (warga_id) REFERENCES warga(id) ON DELETE SET NULL,
  CONSTRAINT fk_js_oleh   FOREIGN KEY (oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE laporan_sektor (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sektor_id  TINYINT UNSIGNED NOT NULL,
  oleh       INT UNSIGNED NULL,
  tanggal    DATE NOT NULL,
  dibuat_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  catatan    TEXT NULL,
  status     ENUM('Terkirim','Diterima') NOT NULL DEFAULT 'Terkirim',
  otomatis   TINYINT(1) NOT NULL DEFAULT 0,
  diterima_oleh INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_ls_status (status),
  CONSTRAINT fk_ls_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_ls_oleh   FOREIGN KEY (oleh) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_ls_terima FOREIGN KEY (diterima_oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE laporan_sektor_item (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  laporan_id INT UNSIGNED NOT NULL,
  aksi       VARCHAR(40) NOT NULL,
  nama       VARCHAR(150) NOT NULL,
  lawan      VARCHAR(100) NULL,
  tanggal    DATE NULL,
  warga_id   INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_lsi_laporan (laporan_id),
  CONSTRAINT fk_lsi_laporan FOREIGN KEY (laporan_id) REFERENCES laporan_sektor(id) ON DELETE CASCADE,
  CONSTRAINT fk_lsi_warga   FOREIGN KEY (warga_id) REFERENCES warga(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE radar_sektor (
  sektor_id   TINYINT UNSIGNED NOT NULL,
  kondisi     ENUM('Kondusif','Butuh Pendampingan','Intervensi Ketua Majelis Jemaat') NULL,
  isu         VARCHAR(255) NULL,
  persetujuan ENUM('Menunggu','Disetujui') NOT NULL DEFAULT 'Disetujui',
  diajukan_oleh INT UNSIGNED NULL,
  disetujui_oleh INT UNSIGNED NULL,
  diubah_pada DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (sektor_id),
  CONSTRAINT fk_rs_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_rs_ajukan FOREIGN KEY (diajukan_oleh) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_rs_setuju FOREIGN KEY (disetujui_oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Catatan pastoral (rahasia): hanya Ketua dan Admin Sektor terkait.
CREATE TABLE catatan_pastoral (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tanggal    DATE NOT NULL,
  sektor_id  TINYINT UNSIGNED NULL COMMENT 'NULL = Semua Sektor',
  nama       VARCHAR(150) NULL COMMENT 'Warga/keluarga yang dilayani',
  jenis      VARCHAR(60) NULL,
  judul      VARCHAR(200) NULL,
  catatan    TEXT NOT NULL,
  tindak_lanjut TEXT NULL,
  status     VARCHAR(40) NOT NULL DEFAULT 'Baru',
  oleh       INT UNSIGNED NULL,
  dibuat     DATE NULL,
  PRIMARY KEY (id),
  KEY idx_cp_sektor (sektor_id, tanggal),
  CONSTRAINT fk_cp_sektor FOREIGN KEY (sektor_id) REFERENCES sektor(id) ON UPDATE CASCADE,
  CONSTRAINT fk_cp_oleh   FOREIGN KEY (oleh) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE audit_log (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  waktu     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id   INT UNSIGNED NULL,
  user_nama VARCHAR(160) NULL,
  aksi      VARCHAR(40) NOT NULL,
  modul     VARCHAR(80) NOT NULL,
  detail    TEXT NULL,
  PRIMARY KEY (id),
  KEY idx_audit_waktu (waktu),
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 9. VIEW: statistik beranda publik
--    Sama dengan aturan di beranda: warga Aktif dan datanya sudah disetujui.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_statistik_publik AS
SELECT
  COUNT(*)                                              AS total_penduduk,
  COALESCE(SUM(kategori = 'Kepala Keluarga'), 0)        AS jumlah_kk,
  COALESCE(SUM(jenis_kelamin = 'Laki-laki'), 0)         AS laki_laki,
  COALESCE(SUM(jenis_kelamin = 'Perempuan'), 0)         AS perempuan,
  (SELECT COUNT(*) FROM sektor)                         AS total_sektor
FROM warga
WHERE status = 'Aktif' AND persetujuan = 'Disetujui';

-- Jumlah warga aktif per sektor
CREATE OR REPLACE VIEW v_warga_per_sektor AS
SELECT s.nama AS sektor, COUNT(w.id) AS jumlah_warga
FROM sektor s
LEFT JOIN warga w ON w.sektor_id = s.id AND w.status = 'Aktif' AND w.persetujuan = 'Disetujui'
GROUP BY s.id, s.nama;

-- Saldo kas keseluruhan (penerimaan + persepuluhan - pengeluaran)
CREATE OR REPLACE VIEW v_saldo_kas AS
SELECT
  (SELECT COALESCE(SUM(jumlah),0) FROM penerimaan)   AS total_penerimaan,
  (SELECT COALESCE(SUM(jumlah),0) FROM persepuluhan) AS total_persepuluhan,
  (SELECT COALESCE(SUM(jumlah),0) FROM pengeluaran)  AS total_pengeluaran,
  (SELECT COALESCE(SUM(jumlah),0) FROM penerimaan)
   + (SELECT COALESCE(SUM(jumlah),0) FROM persepuluhan)
   - (SELECT COALESCE(SUM(jumlah),0) FROM pengeluaran) AS saldo_kas;

-- ---------------------------------------------------------------------
-- 10. DATA AWAL
-- ---------------------------------------------------------------------
INSERT INTO sektor (nama) VALUES
  ('Sektor Sion'),('Sektor Galelia'),('Sektor Ebenhaezer'),
  ('Sektor Getsemany'),('Sektor Tiberias'),('Sektor Betlehem');

INSERT INTO pengaturan (kunci, nilai) VALUES
  ('sentralisasi_kas_jemaat_persen', '75'),
  ('sentralisasi_klasis_sinode_persen', '25');

-- Akun Admin pertama: buat lewat aplikasi (password harus di-hash di server).
-- Contoh (ganti HASH_BCRYPT dengan hash sebenarnya):
-- INSERT INTO users (nama, username, email, role, status, akses_keuangan, password_hash)
-- VALUES ('Admin Jemaat', 'admin', 'admin@contoh.id', 'admin', 'aktif', 1, 'HASH_BCRYPT');

-- Opsional: akun MySQL khusus aplikasi (ganti password).
-- CREATE USER 'gpm_app'@'localhost' IDENTIFIED BY 'GANTI_PASSWORD_KUAT';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON gpm_tihulale.* TO 'gpm_app'@'localhost';
-- FLUSH PRIVILEGES;
