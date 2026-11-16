package scratchduino.robot.ui.v1;

import java.awt.Image;
import java.awt.PopupMenu;
import java.awt.SystemTray;
import java.awt.TrayIcon;
import java.lang.reflect.Field;

/**
 * Замена `new TrayIcon(...)` в статическом инициализаторе ControlPanel.
 * Без системного трея (GNOME без расширения, минимальные оконные менеджеры, Xvfb) конструктор
 * TrayIcon бросает UnsupportedOperationException, ControlPanel не загружается, и панель падает.
 * Иконку в трей панель добавляет только при SystemTray.isSupported(), поэтому здесь достаточно
 * вернуть объект, у которого работает setImage().
 */
public final class TrayIcons {
    private TrayIcons() {
    }

    public static TrayIcon create(Image image, String tooltip, PopupMenu popup) {
        if (SystemTray.isSupported()) {
            return new TrayIcon(image, tooltip, popup);
        }
        try {
            Field f = sun.misc.Unsafe.class.getDeclaredField("theUnsafe");
            f.setAccessible(true);
            sun.misc.Unsafe unsafe = (sun.misc.Unsafe) f.get(null);
            // Объект без вызова конструктора: peer == null, setImage() только запоминает картинку
            TrayIcon icon = (TrayIcon) unsafe.allocateInstance(TrayIcon.class);
            icon.setImage(image);
            return icon;
        } catch (Throwable e) {
            System.err.println("TrayIcon is not available: " + e);
            return null;
        }
    }
}
