/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

/*
 * The user's remotes. Only the pointer into the database is kept (its file
 * and layout) plus the name the user gave it, so a newer database with fixed
 * codes reaches remotes that were added before it.
 */

var _db = null;

function _open() {
    if (_db !== null)
        return _db;

    _db = Sql.LocalStorage.openDatabaseSync("org.webosports.app.remote", "1.0", "Remotes", 100000);
    _db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS remotes (" +
                      "id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, file TEXT, " +
                      "category TEXT, layout TEXT, brand TEXT, model TEXT, position INTEGER)");
    });
    return _db;
}

function list() {
    var result = [];

    _open().readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT * FROM remotes ORDER BY position, id");

        for (var i = 0; i < rs.rows.length; i++)
            result.push(rs.rows.item(i));
    });
    return result;
}

function add(name, file, category, layout, brand, model) {
    var id = -1;

    _open().transaction(function(tx) {
        var rs = tx.executeSql("SELECT COALESCE(MAX(position), 0) + 1 AS next FROM remotes");
        var r = tx.executeSql("INSERT INTO remotes (name, file, category, layout, brand, model, position) " +
                              "VALUES (?, ?, ?, ?, ?, ?, ?)",
                              [name, file, category, layout, brand, model, rs.rows.item(0).next]);
        id = parseInt(r.insertId, 10);
    });
    return id;
}

function rename(id, name) {
    _open().transaction(function(tx) {
        tx.executeSql("UPDATE remotes SET name = ? WHERE id = ?", [name, id]);
    });
}

function remove(id) {
    _open().transaction(function(tx) {
        tx.executeSql("DELETE FROM remotes WHERE id = ?", [id]);
    });
}
