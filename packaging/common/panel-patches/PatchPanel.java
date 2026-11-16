import org.springframework.asm.ClassReader;
import org.springframework.asm.ClassVisitor;
import org.springframework.asm.ClassWriter;
import org.springframework.asm.MethodVisitor;
import org.springframework.asm.Opcodes;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/**
 * Правит три класса панели байткодом (исходников нет). Запуск: PatchPanel <каталог-in> <каталог-out>,
 * в обоих — дерево scratchduino/robot/... Уже пропатченный класс (в нём есть имя TrayIcons/RobboLog) пропускается.
 *
 *  ControlPanel.<clinit>            new TrayIcon(...)         -> TrayIcons.create(...)
 *  Main.<clinit>                    в начало                  -> RobboLog.init()
 *  ScratchExternalCommand           ProcessBuilder.start()    -> RobboLog.start(ProcessBuilder)
 *                                   Runtime.exec("./" + cmd)  -> RobboLog.exec(Runtime, String)
 */
public class PatchPanel {
    static final String CONTROL_PANEL = "scratchduino/robot/ui/v1/ControlPanel";
    static final String MAIN = "scratchduino/robot/Main";
    static final String EXTERNAL = "scratchduino/robot/ScratchExternalCommand";
    static final String TRAY_ICONS = "scratchduino/robot/ui/v1/TrayIcons";
    static final String ROBBO_LOG = "scratchduino/robot/RobboLog";

    public static void main(String[] args) throws Exception {
        patch(args[0], args[1], CONTROL_PANEL, TRAY_ICONS, 1);
        patch(args[0], args[1], MAIN, ROBBO_LOG, 1);
        patch(args[0], args[1], EXTERNAL, ROBBO_LOG, 2);
    }

    static void patch(String inDir, String outDir, final String cls, String marker, final int expected) throws Exception {
        byte[] in = Files.readAllBytes(new File(inDir, cls + ".class").toPath());
        if (new String(in, StandardCharsets.ISO_8859_1).contains(marker)) {
            System.out.println("уже пропатчен: " + cls);
            return;
        }
        final int[] count = {0};
        ClassWriter writer = new ClassWriter(0);
        new ClassReader(in).accept(new ClassVisitor(Opcodes.ASM5, writer) {
            public MethodVisitor visitMethod(int access, final String name, String desc, String sig, String[] ex) {
                MethodVisitor mv = super.visitMethod(access, name, desc, sig, ex);
                if (cls.equals(CONTROL_PANEL) && name.equals("<clinit>")) return trayPatch(mv, count);
                if (cls.equals(MAIN) && name.equals("<clinit>")) return initPatch(mv, count);
                if (cls.equals(EXTERNAL)) return launchPatch(mv, count);
                return mv;
            }
        }, 0);
        if (count[0] != expected) throw new IllegalStateException(cls + ": ожидалось замен " + expected + ", сделано " + count[0]);
        File out = new File(outDir, cls + ".class");
        out.getParentFile().mkdirs();
        Files.write(out.toPath(), writer.toByteArray());
        System.out.println("пропатчен: " + cls + " (" + count[0] + ")");
    }

    static MethodVisitor trayPatch(MethodVisitor mv, final int[] count) {
        return new MethodVisitor(Opcodes.ASM5, mv) {
            boolean skipDup;
            public void visitTypeInsn(int opcode, String type) {
                if (opcode == Opcodes.NEW && type.equals("java/awt/TrayIcon")) { skipDup = true; return; }
                super.visitTypeInsn(opcode, type);
            }
            public void visitInsn(int opcode) {
                if (skipDup && opcode == Opcodes.DUP) { skipDup = false; return; }
                super.visitInsn(opcode);
            }
            public void visitMethodInsn(int opcode, String owner, String n, String d, boolean itf) {
                if (opcode == Opcodes.INVOKESPECIAL && owner.equals("java/awt/TrayIcon") && n.equals("<init>")) {
                    count[0]++;
                    super.visitMethodInsn(Opcodes.INVOKESTATIC, TRAY_ICONS, "create",
                            "(Ljava/awt/Image;Ljava/lang/String;Ljava/awt/PopupMenu;)Ljava/awt/TrayIcon;", false);
                    return;
                }
                super.visitMethodInsn(opcode, owner, n, d, itf);
            }
        };
    }

    static MethodVisitor initPatch(MethodVisitor mv, final int[] count) {
        return new MethodVisitor(Opcodes.ASM5, mv) {
            public void visitCode() {
                super.visitCode();
                count[0]++;
                super.visitMethodInsn(Opcodes.INVOKESTATIC, ROBBO_LOG, "init", "()V", false);
            }
        };
    }

    static MethodVisitor launchPatch(MethodVisitor mv, final int[] count) {
        return new MethodVisitor(Opcodes.ASM5, mv) {
            boolean sawDotSlash;
            public void visitLdcInsn(Object value) {
                if ("./".equals(value)) sawDotSlash = true;
                super.visitLdcInsn(value);
            }
            public void visitMethodInsn(int opcode, String owner, String n, String d, boolean itf) {
                if (opcode == Opcodes.INVOKEVIRTUAL && owner.equals("java/lang/ProcessBuilder") && n.equals("start")) {
                    count[0]++;
                    super.visitMethodInsn(Opcodes.INVOKESTATIC, ROBBO_LOG, "start",
                            "(Ljava/lang/ProcessBuilder;)Ljava/lang/Process;", false);
                    return;
                }
                if (sawDotSlash && opcode == Opcodes.INVOKEVIRTUAL && owner.equals("java/lang/Runtime")
                        && n.equals("exec") && d.equals("(Ljava/lang/String;)Ljava/lang/Process;")) {
                    sawDotSlash = false;
                    count[0]++;
                    super.visitMethodInsn(Opcodes.INVOKESTATIC, ROBBO_LOG, "exec",
                            "(Ljava/lang/Runtime;Ljava/lang/String;)Ljava/lang/Process;", false);
                    return;
                }
                super.visitMethodInsn(opcode, owner, n, d, itf);
            }
        };
    }
}
