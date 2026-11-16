package scratchduino.robot;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.StringTokenizer;

/**
 * Журналы Java-панели. Вызывается из кода панели, пропатченного PatchPanel:
 * <ul>
 *   <li>Main.&lt;clinit&gt; зовёт init(): выбирает каталог журналов и кладёт его в системное свойство
 *       robbo.log.dir до старта log4j (log4j.xml пишет log.txt в ${robbo.log.dir}log.txt);</li>
 *   <li>запуск окна Junior (ScratchExternalCommand) идёт через start()/exec(): вывод процесса
 *       (stdout и stderr) пишется в junior.out.log, код выхода попадает в панельный журнал.
 *       Без этого stderr окна терялся, и ранние падения (песочница Chromium, GPU) были невидимы.</li>
 * </ul>
 * Каталог берётся из переменных окружения внутри Java (Unicode), а не из командной строки:
 * путь с кириллицей в аргументе java.exe на Windows портится.
 * Windows: %LOCALAPPDATA%\RobboJuniorLogs; Linux: $XDG_STATE_HOME/robboJunior или ~/.local/state/robboJunior.
 */
public final class RobboLog {
    private static final String PROPERTY = "robbo.log.dir";

    private RobboLog() {
    }

    public static synchronized void init() {
        String dir = "";
        try {
            dir = dir();
            Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
                public void uncaughtException(Thread t, Throwable e) {
                    System.err.println("[panel] uncaught exception in thread " + t.getName());
                    e.printStackTrace();
                }
            });
            System.err.println("[panel] java " + System.getProperty("java.version") + ", "
                    + System.getProperty("os.name") + " " + System.getProperty("os.version")
                    + ", file.encoding=" + System.getProperty("file.encoding")
                    + ", user.dir=" + System.getProperty("user.dir") + ", logs=" + dir);
        } catch (Throwable e) {
            System.err.println("[panel] logging is not set up: " + e);
        }
        System.setProperty(PROPERTY, dir);
    }

    /** Каталог журналов с разделителем в конце; пустая строка — писать в текущий каталог, как раньше. */
    public static String dir() {
        String set = System.getProperty(PROPERTY);
        if (set != null && !set.isEmpty()) {
            return set;
        }
        File dir;
        String os = System.getProperty("os.name", "").toLowerCase();
        if (os.contains("win")) {
            String base = System.getenv("LOCALAPPDATA");
            if (base == null || base.isEmpty()) {
                base = System.getProperty("user.home");
            }
            dir = new File(base, "RobboJuniorLogs");
        } else {
            String state = System.getenv("XDG_STATE_HOME");
            // $HOME, а не user.home: так же, как в robboJunior-launcher.sh, где лежит panel.log
            String home = System.getenv("HOME");
            if (home == null || home.isEmpty()) {
                home = System.getProperty("user.home");
            }
            dir = (state != null && !state.isEmpty())
                    ? new File(state, "robboJunior")
                    : new File(home, ".local/state/robboJunior");
        }
        if (!dir.isDirectory() && !dir.mkdirs()) {
            return "";
        }
        return dir.getPath() + File.separator;
    }

    /** Замена ProcessBuilder.start() при запуске окна Junior (Windows). */
    public static Process start(ProcessBuilder builder) throws IOException {
        return launch(builder);
    }

    /** Замена Runtime.exec(String) при запуске окна Junior (Linux). Разбор строки такой же, как у Runtime. */
    public static Process exec(Runtime runtime, String command) throws IOException {
        List<String> parts = new ArrayList<String>();
        StringTokenizer tokens = new StringTokenizer(command);
        while (tokens.hasMoreTokens()) {
            parts.add(tokens.nextToken());
        }
        return launch(new ProcessBuilder(parts));
    }

    private static Process launch(ProcessBuilder builder) throws IOException {
        final File out = prepareOutput(builder);
        final Process process = builder.start();
        final String what = String.valueOf(builder.command());
        Thread watcher = new Thread("junior-exit-watcher") {
            public void run() {
                try {
                    int code = process.waitFor();
                    String text = "[junior] " + what + " exited with code " + code
                            + (code > 128 && code < 160 ? " (signal " + (code - 128) + ")" : "");
                    System.err.println(text);
                    append(out, text);
                } catch (InterruptedException ignored) {
                    // panel is closing
                }
            }
        };
        watcher.setDaemon(true);
        watcher.start();
        return process;
    }

    /** Перенаправляет вывод процесса в junior.out.log; предыдущий журнал остаётся как junior.out.old.log. */
    private static File prepareOutput(ProcessBuilder builder) {
        try {
            String dir = dir();
            if (dir.isEmpty()) {
                return null;
            }
            File out = new File(dir, "junior.out.log");
            File old = new File(dir, "junior.out.old.log");
            if (out.exists()) {
                old.delete();
                out.renameTo(old);
            }
            File cwd = builder.directory() != null ? builder.directory() : new File(System.getProperty("user.dir"));
            append(out, "start " + builder.command() + ", cwd=" + cwd);
            builder.redirectErrorStream(true);
            builder.redirectOutput(ProcessBuilder.Redirect.appendTo(out));
            return out;
        } catch (Throwable e) {
            System.err.println("[junior] output is not redirected: " + e);
            return null;
        }
    }

    private static void append(File file, String line) {
        if (file == null) {
            return;
        }
        try {
            FileWriter writer = new FileWriter(file, true);
            try {
                writer.write(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date()) + " " + line + "\n");
            } finally {
                writer.close();
            }
        } catch (IOException ignored) {
            // the log folder is not writable: nothing else to do
        }
    }
}
