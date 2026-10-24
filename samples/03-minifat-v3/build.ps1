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
	static readonly int[] SIZES = {
		4000, 3000, 100, 1, 64, 4095, 2000, 65,
		3500, 4032, 129, 2500, 3999, 640, 3800, 4090,
	};

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

		IStream big = stg.CreateStream("Big", MODE, 0, 0);
		IStream[] m = new IStream[SIZES.Length];
		for (int i = 0; i < m.Length; i++)
			m[i] = stg.CreateStream("M" + i, MODE, 0, 0);

		long boff = 0;
		for (int off = 0; off < 4096; off += 64) {
			for (int i = 0; i < m.Length; i++)
				if (off < SIZES[i]) put(m[i], off, Math.Min(64, SIZES[i] - off), i);
			put(big, boff, 512, 100);
			boff += 512;
		}
		for (int i = 0; i < m.Length; i++)
			check(m[i], 0, SIZES[i], i);

		Marshal.ReleaseComObject(m[2]);
		stg.DestroyElement("M2");
		Marshal.ReleaseComObject(m[11]);
		stg.DestroyElement("M11");

		m[1].SetSize(1000);
		check(m[1], 0, 1000, 1);

		put(m[4], 64, 5000 - 64, 4);
		check(m[4], 0, 5000, 4);

		IStream t = stg.CreateStream("T", MODE, 0, 0);
		put(t, 0, 8192, 200);
		t.SetSize(200);
		check(t, 0, 200, 200);

		IStream n = stg.CreateStream("N", MODE, 0, 0);
		put(n, 0, 3000, 201);
		check(n, 0, 3000, 201);

		check(big, 0, (int)boff, 100);
		stg.Commit(0);
		Marshal.ReleaseComObject(big);
		Marshal.ReleaseComObject(t);
		Marshal.ReleaseComObject(n);
		for (int i = 0; i < m.Length; i++)
			if (i != 2 && i != 11) Marshal.ReleaseComObject(m[i]);
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
