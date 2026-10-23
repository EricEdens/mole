param([string]$Dir = '.')
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

[ComImport, Guid("0000000B-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IStorage {
	IStream CreateStream([MarshalAs(UnmanagedType.LPWStr)] string name, uint mode, uint r1, uint r2);
	IStream OpenStream([MarshalAs(UnmanagedType.LPWStr)] string name, IntPtr r1, uint mode, uint r2);
	IStorage CreateStorage([MarshalAs(UnmanagedType.LPWStr)] string name, uint mode, uint r1, uint r2);
	IStorage OpenStorage([MarshalAs(UnmanagedType.LPWStr)] string name, IntPtr prio, uint mode, IntPtr excl, uint r);
	void CopyTo(uint n, IntPtr excl, IntPtr snb, IStorage dst);
	void MoveElementTo([MarshalAs(UnmanagedType.LPWStr)] string name, IStorage dst, [MarshalAs(UnmanagedType.LPWStr)] string newname, uint flags);
	void Commit(uint flags);
	void Revert();
	void EnumElements(uint r1, IntPtr r2, uint r3, out IntPtr e);
	void DestroyElement([MarshalAs(UnmanagedType.LPWStr)] string name);
}

public static class Stg {
	[DllImport("ole32.dll")]
	static extern int StgCreateDocfile([MarshalAs(UnmanagedType.LPWStr)] string path, uint mode, uint rsv, out IStorage stg);

	const uint MODE = 0x12;
	const int K = 4096;
	const int M = 1 << 20;

	static byte[] pat(long off, int n, int seed) {
		byte[] b = new byte[n];
		for (int i = 0; i < n; i++)
			b[i] = (byte)((off + i + seed) % 251);
		return b;
	}
	static void put(IStream s, long off, int n, int seed) {
		s.Seek(off, 0, IntPtr.Zero);
		s.Write(pat(off, n, seed), n, IntPtr.Zero);
	}
	static void check(IStream s, long off, int n, int seed) {
		byte[] b = new byte[n], w = pat(off, n, seed);
		s.Seek(off, 0, IntPtr.Zero);
		s.Read(b, n, IntPtr.Zero);
		for (int i = 0; i < n; i++)
			if (b[i] != w[i]) throw new Exception(string.Format("check: seed {0} off {1}", seed, off + i));
	}

	public static void Make(string path) {
		IStorage stg;
		int hr = StgCreateDocfile(path, 0x1012, 0, out stg);
		if (hr != 0) throw new Exception(string.Format("StgCreateDocfile: 0x{0:x8}", hr));

		IStream a = stg.CreateStream("A", MODE, 0, 0);
		IStream b = stg.CreateStream("B", MODE, 0, 0);
		IStream c = stg.CreateStream("C", MODE, 0, 0);
		for (long off = 0; off < 7L * M; off += K) {
			put(a, off, K, 0);
			put(b, off, K, 1);
			if (off < 6L * M) put(c, off, K, 2);
		}
		check(a, 0, M, 0);
		check(b, 3L * M + 100, M, 1);
		check(c, 6L * M - K, K, 2);

		Marshal.ReleaseComObject(b);
		stg.DestroyElement("B");

		IStream d = stg.CreateStream("D", MODE, 0, 0);
		for (long off = 0; off < 5L * M; off += K)
			put(d, off, K, 3);
		check(a, 7L * M - K, K, 0);
		check(d, 0, 5 * M, 3);

		c.SetSize(3L * M);
		check(c, 3L * M - K, K, 2);

		for (long off = 7L * M; off < 8L * M; off += K)
			put(a, off, K, 0);
		check(a, 0, 8 * M, 0);

		IStream e = stg.CreateStream("E", MODE, 0, 0);
		put(e, 0, 100, 4);
		check(e, 0, 100, 4);

		stg.Commit(0);
		Marshal.ReleaseComObject(a);
		Marshal.ReleaseComObject(c);
		Marshal.ReleaseComObject(d);
		Marshal.ReleaseComObject(e);
		Marshal.ReleaseComObject(stg);
	}
}
'@
$v = (Get-Item "$env:SystemRoot\System32\coml2.dll").VersionInfo.FileVersionRaw
$r = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
$slug = 'win{0}-{1}-{2}.{3}-{4}' -f ($(if ($v.Build -ge 22000) { 11 } else { 10 }),
    $r.ToLower(), $v.Build, $v.Revision, $env:PROCESSOR_ARCHITECTURE.ToLower())
$Path = Join-Path (Resolve-Path $Dir) "$slug.cfb"
[Stg]::Make($Path)
Get-Item $Path | Select-Object FullName, Length
