using System;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;
using System.Media;

class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        string title = args.Length > 0 ? args[0] : "AudioScrap";
        string body = args.Length > 1 ? args[1] : "";

        using NotifyIcon icon = new NotifyIcon();
        icon.Visible = true;
        icon.Icon = SystemIcons.Application;
        icon.BalloonTipTitle = title;
        icon.BalloonTipText = body;
        icon.ShowBalloonTip(5000);

        // Play a short completion sound
        try {
            SystemSounds.Asterisk.Play();
        } catch { }

        // Keep the process alive briefly so the balloon and sound are shown/played
        Thread.Sleep(4500);
        return 0;
    }
}
