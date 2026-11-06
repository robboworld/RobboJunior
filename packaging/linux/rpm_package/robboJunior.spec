%define name robboJunior
%define version 1.0.0
%define release 1

# Шаблон: build_rpm.sh подставляет версию, тексты скриптов после установки/удаления
# (из packaging/linux/files) и список встроенных библиотек, а готовое дерево
# установки передаёт через --define "rj_stage <каталог>".

Summary: Robbo Junior - visual programming for young children
Name: %{name}
Version: %{version}
Release: %{release}
License: BSD-3-Clause
Group: Education
URL: https://robboclub.ru
Vendor: Robbo Team
Packager: Robbo Team <support@robboclub.ru>
ExclusiveArch: x86_64

# Бинарный пакет: без отладочных подпакетов, strip и пересжатия (Electron и Java уже собраны)
%global debug_package %{nil}
%global __os_install_post %{nil}
%define __strip /bin/true

# Встроенные Electron и Java не должны объявлять свои .so системными
%global __provides_exclude_from ^/opt/robboJunior/.*$
# Зависимости от библиотек, которые лежат внутри пакета, и от интерпретаторов
# (на ALT p11 нет /usr/bin/python) — исключаются; список .so добавляет build_rpm.sh
%global __requires_exclude ^(/usr/bin/python[0-9.]*|/usr/bin/perl@BUNDLED_LIBS@)

Obsoletes: robbojunior
Conflicts: robbojunior

%description
Robbo Junior is a block-based programming environment for children
aged 5-8, based on ScratchJr, with support for Robbo robots.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a %{rj_stage}/. %{buildroot}/

%post
@POST_INSTALL@

%postun
if [ "$1" = "0" ]; then
@POST_REMOVE@
fi

%files
%defattr(-,root,root,-)
/opt/robboJunior
/usr/bin/robboJunior
/usr/share/applications/robboJunior.desktop
/usr/share/applications/robboJunior-panel.desktop
/usr/share/pixmaps/robboJunior.png
/usr/lib/udev/rules.d/86-robbojunior-ch340.rules
