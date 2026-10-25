param([string]$Dir = '.')
Add-Type @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
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
	const int EXISTS = unchecked((int)0x80030050);
	const string ALPHA = "\u0001 0AaXxz_~\u00b5\u00c9\u00e9\u00ff\u0178\u01c5\u03a3\u03c2\u03c3\uff5a\uffff";

	static string Hex(string s) {
		StringBuilder sb = new StringBuilder();
		foreach (char c in s) sb.AppendFormat("{0:x4}", (int)c);
		return sb.ToString();
	}

	static void Add(IStorage stg, string n, StringBuilder log) {
		try {
			IStream w = stg.CreateStream(n, MODE, 0, 0);
			w.Write(Encoding.Unicode.GetBytes(n), n.Length * 2, IntPtr.Zero);
			Marshal.ReleaseComObject(w);
			return;
		} catch (COMException e) {
			if (e.HResult != EXISTS) {
				log.AppendFormat("{0}\t{1:x8}\n", Hex(n), e.HResult);
				return;
			}
		}
		IStream s = stg.OpenStream(n, IntPtr.Zero, MODE, 0);
		byte[] b = new byte[n.Length * 2];
		s.Read(b, b.Length, IntPtr.Zero);
		Marshal.ReleaseComObject(s);
		log.AppendFormat("{0}\t={1}\n", Hex(n), Hex(Encoding.Unicode.GetString(b)));
	}

	public static void Make(string path, string log) {
		IStorage stg;
		int hr = StgCreateDocfile(path, 0x1012, 0, out stg);
		if (hr != 0) throw new Exception(string.Format("StgCreateDocfile: 0x{0:x8}", hr));

		StringBuilder sb = new StringBuilder();
		for (int l = 1; l < 32; l++)
			for (int p = 0; p < l; p++)
				foreach (char c in ALPHA) {
					char[] n = new string('x', l).ToCharArray();
					n[p] = c;
					Add(stg, new string(n), sb);
				}

		uint x = 0x12345678;
		for (int i = 0; i < 4096; i++) {
			x = x * 1103515245 + 12345;
			char[] n = new char[1 + (x >> 16) % 31];
			for (int j = 0; j < n.Length; j++) {
				x = x * 1103515245 + 12345;
				n[j] = ALPHA[(int)((x >> 16) % (uint)ALPHA.Length)];
			}
			Add(stg, new string(n), sb);
		}
		stg.Commit(0);
		Marshal.ReleaseComObject(stg);
		File.WriteAllText(log, sb.ToString());
	}
}
'@
$v = (Get-Item "$env:SystemRoot\System32\coml2.dll").VersionInfo.FileVersionRaw
$r = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
$slug = 'win{0}-{1}-{2}.{3}-{4}' -f ($(if ($v.Build -ge 22000) { 11 } else { 10 }),
    $r.ToLower(), $v.Build, $v.Revision, $env:PROCESSOR_ARCHITECTURE.ToLower())
$Path = Join-Path (Resolve-Path $Dir) "$slug.cfb"
$Log = Join-Path (Resolve-Path $Dir) "$slug.txt"
[Stg]::Make($Path, $Log)
Get-Item $Path, $Log | Select-Object FullName, Length
