import {gn, newHTML} from '../utils/lib';
import Localization from '../utils/Localization';
import IO from '../tablet/IO';

/*
 What's new: release messages from whats-new.json, written into the build by scripts/build.sh, so it works
 offline. The version on the home screen opens the window, a red dot on it marks unread releases, and the
 window opens by itself only for an [Important] item. Unread means newer than the release last shown;
 on a first run or after a version without a message, only the newest release.
*/

const LAST_SEEN_KEY = 'robbo.whatsnew.seen';
const SECTION_KEYS = ['added', 'changed', 'fixed'];

let releases = [];

function readLastSeen () {
    try {
        return window.localStorage.getItem(LAST_SEEN_KEY) || '';
    } catch (e) {
        return '';
    }
}

function writeLastSeen (version) {
    try {
        window.localStorage.setItem(LAST_SEEN_KEY, version);
    } catch (e) {
        // storage unavailable: the dot simply shows again next time
    }
}

export default class WhatsNew {
    static init () {
        IO.requestFromServer('whats-new.json', function (text) {
            try {
                releases = JSON.parse(text).releases;
            } catch (e) {
                return; // no file: the version stays plain text
            }
            if (releases.length > 0) {
                WhatsNew.enable();
            }
        });
    }

    static unreadReleases () {
        var seen = readLastSeen();
        for (var i = 0; i < releases.length; i++) {
            if (releases[i].version == seen) {
                return releases.slice(0, i);
            }
        }
        return releases.slice(0, 1);
    }

    static enable () {
        var version = gn('version');
        var unread = WhatsNew.unreadReleases();
        version.className = (unread.length > 0) ? 'whatsnew unread' : 'whatsnew';
        version.onclick = WhatsNew.open;
        if (unread.some(release => release.important)) {
            WhatsNew.open();
        }
    }

    static open () {
        var overlay = newHTML('div', 'whatsnew-overlay', document.body);
        var win = newHTML('div', 'whatsnew-window', overlay);
        newHTML('h1', undefined, win).textContent = Localization.localize('WHATS_NEW');

        var list = newHTML('div', 'whatsnew-list', win);
        var language = Localization.currentLocale.indexOf('ru') == 0 ? 'ru' : 'en';
        releases.forEach(release => WhatsNew.addRelease(list, release, release[language]));

        var ok = newHTML('div', 'whatsnew-ok', win);
        ok.textContent = Localization.localize('WHATS_NEW_OK');
        ok.onclick = close;

        // The overlay covers the version too, so a click on it closes the window as well
        overlay.onclick = function (e) {
            if (e.target == overlay) {
                close();
            }
        };

        function close () {
            document.body.removeChild(overlay);
        }

        writeLastSeen(releases[0].version);
        gn('version').className = 'whatsnew';
    }

    static addRelease (list, release, note) {
        var header = newHTML('h2', undefined, list);
        header.textContent = release.version;
        newHTML('span', undefined, header).textContent = release.date;

        if (note.intro) {
            newHTML('p', undefined, list).textContent = note.intro;
        }
        var items = newHTML('ul', undefined, list);
        SECTION_KEYS.forEach(function (key) {
            note.sections[key].forEach(function (item) {
                var line = newHTML('li', undefined, items);
                newHTML('b', undefined, line).textContent = item.title + ': ';
                line.appendChild(document.createTextNode(item.text));
            });
        });
    }
}
