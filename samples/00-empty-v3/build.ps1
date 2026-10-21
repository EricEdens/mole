param([string]$Dir = '.')
Add-Type @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using STATSTG = System.Runtime.InteropServices.ComTypes.STATSTG;

[ComImport, Guid("0000000A-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface ILockBytes {
	[PreserveSig] int ReadAt(ulong off, IntPtr pv, uint cb, out uint n);
	[PreserveSig] int WriteAt(ulong off, IntPtr pv, uint cb, out uint n);
	[PreserveSig] int Flush();
	[PreserveSig] int SetSize(ulong cb);
	[PreserveSig] int LockRegion(ulong off, ulong cb, uint type);
	[PreserveSig] int UnlockRegion(ulong off, ulong cb, uint type);
	[PreserveSig] int Stat(out STATSTG st, uint flag);
}

[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
public class MemLockBytes : ILockBytes {
	public byte[] buf = new byte[0];
	public long len;

	void grow(long n) {
		if (n > buf.Length) Array.Resize(ref buf, (int)Math.Max(n, 2L * buf.Length));
		if (n > len) len = n;
	}
	public int ReadAt(ulong off, IntPtr pv, uint cb, out uint n) {
		long k = Math.Max(0, Math.Min((long)cb, len - (long)off));
		if (k > 0) Marshal.Copy(buf, (int)off, pv, (int)k);
		n = (uint)k;
		return 0;
	}
	public int WriteAt(ulong off, IntPtr pv, uint cb, out uint n) {
		grow((long)off + cb);
		Marshal.Copy(pv, buf, (int)off, (int)cb);
		n = cb;
		return 0;
	}
	public int Flush() { return 0; }
	public int SetSize(ulong cb) {
		grow((long)cb);
		len = (long)cb;
		return 0;
	}
	public int LockRegion(ulong off, ulong cb, uint type) { return 0; }
	public int UnlockRegion(ulong off, ulong cb, uint type) { return 0; }
	public int Stat(out STATSTG st, uint flag) {
		st = new STATSTG();
		st.type = 3;
		st.cbSize = len;
		return 0;
	}
	public byte[] Bytes() {
		byte[] b = new byte[len];
		Array.Copy(buf, b, len);
		return b;
	}
}

public static class Stg {
	[DllImport("ole32.dll")]
	static extern int StgCreateDocfileOnILockBytes(ILockBytes lb, uint mode, uint rsv, out IntPtr stg);

	public static void Make(string path) {
		MemLockBytes lb = new MemLockBytes();
		IntPtr stg;
		int hr = StgCreateDocfileOnILockBytes(lb, 0x1012, 0, out stg);
		if (hr != 0) throw new Exception(string.Format("StgCreateDocfileOnILockBytes: 0x{0:x8}", hr));
		File.WriteAllBytes(path, lb.Bytes());
		Marshal.Release(stg);
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
