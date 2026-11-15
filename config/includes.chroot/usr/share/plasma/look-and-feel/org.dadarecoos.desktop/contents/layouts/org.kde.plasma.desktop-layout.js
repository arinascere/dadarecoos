// DadarecoOS: barra fina no topo (menu, menu global, bandeja, relógio) e dock
// flutuante centralizado embaixo. As duas alturas abaixo são trocadas pelo
// post-install.sh quando "tela sensível ao toque" é marcado.
// ponytail: escrito sem testar num Plasma real; ajustar após o primeiro boot.
var TOP_HEIGHT = 28;
var DOCK_HEIGHT = 56;

var topBar = new Panel;
topBar.location = "top";
topBar.height = TOP_HEIGHT;
var menu = topBar.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "/usr/share/pixmaps/dadarecoos.png");
topBar.addWidget("org.kde.plasma.appmenu");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");
topBar.addWidget("org.kde.plasma.digitalclock");

var dock = new Panel;
dock.location = "bottom";
dock.height = DOCK_HEIGHT;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.floating = true;
dock.hiding = "dodgewindows";
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:firefox-esr.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:libreoffice-writer.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
]);

var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; i++) {
    desktops[i].wallpaperPlugin = "org.kde.image";
    desktops[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktops[i].writeConfig("Image", "file:///usr/share/backgrounds/dadarecoos/default.png");
}
