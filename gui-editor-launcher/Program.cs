using System.Diagnostics;
using System.Text;

public class Program
{
    private static Process? factorioProcess;
    private static bool restarting;

    public static void Main()
    {
        ///cSpell:ignore jmpc4
        ProcessStartInfo startInfo = new("/mnt/big/portable/factorio/bin/x64/factorio")
        {
            ArgumentList = {
                "",
                "",
                "--window-size",
                "1280x720",
                "--mod-directory",
                "/home/jmpc4/dev/FactorioGUIEditor/mods/",
            },
            RedirectStandardOutput = true,
            StandardOutputEncoding = Encoding.UTF8,
        };
        do
        {
            restarting = false;
            if (File.Exists("/mnt/big/portable/factorio/saves/_autosave-gui-editor.zip"))
            {
                startInfo.ArgumentList[0] = "--load-game";
                startInfo.ArgumentList[1] = "_autosave-gui-editor";
            }
            else
            {
                startInfo.ArgumentList[0] = "--load-scenario";
                startInfo.ArgumentList[1] = "JanSharpDevEnv/NoBase";
            }
            factorioProcess = Process.Start(startInfo);
            if (factorioProcess == null)
                return;
            factorioProcess.OutputDataReceived += OnOutputDataReceived;
            factorioProcess.BeginOutputReadLine();
            factorioProcess.WaitForExit();
            factorioProcess.Close();
            factorioProcess = null;
        }
        while (restarting);
    }

    private static void OnOutputDataReceived(object sender, DataReceivedEventArgs e)
    {
        if (e.Data == null || !e.Data.StartsWith("<>") || !e.Data.EndsWith("<>") || factorioProcess == null)
            return;
        if (!factorioProcess.CloseMainWindow())
            factorioProcess.Kill();
        restarting = true;
    }
}
