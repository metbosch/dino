using Gee;
using Qlite;
using Xmpp;

using Dino.Entities;

namespace Dino {

public class Database : Qlite.Database {
    private const int VERSION = 10;

    public class AccountTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<string> bare_jid = new Column.Text("bare_jid") { unique = true, not_null = true };
        public Column<string> resourcepart = new Column.Text("resourcepart");
        public Column<string> password = new Column.Text("password");
        public Column<string> alias = new Column.Text("alias");
        public Column<bool> enabled = new Column.BoolInt("enabled");
        public Column<string> roster_version = new Column.Text("roster_version") { min_version=2 };
        public Column<long> mam_earliest_synced = new Column.Long("mam_earliest_synced") { min_version=4 };
        public Column<string> servername = new Column.Text("servername") { min_version=10 };

        internal AccountTable(Database db) {
            base(db, "account");
            init({id, bare_jid, resourcepart, password, alias, enabled, roster_version, mam_earliest_synced, servername});
        }
    }

    public class JidTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<string> bare_jid = new Column.Text("bare_jid") { unique = true, not_null = true };

        internal JidTable(Database db) {
            base(db, "jid");
            init({id, bare_jid});
        }
    }

    public class ContentItemTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<int> conversation_id = new Column.Integer("conversation_id") { not_null = true };
        public Column<long> time = new Column.Long("time") { not_null = true };
        public Column<long> local_time = new Column.Long("local_time") { not_null = true };
        public Column<int> content_type = new Column.Integer("content_type") { not_null = true };
        public Column<int> foreign_id = new Column.Integer("foreign_id") { not_null = true };
        public Column<bool> hide = new Column.BoolInt("hide") { default = "0", not_null = true, min_version = 9 };

        internal ContentItemTable(Database db) {
            base(db, "content_item");
            init({id, conversation_id, time, local_time, content_type, foreign_id, hide});
            index("contentitem_localtime_counterpart_idx", {local_time, conversation_id});
            unique({content_type, foreign_id}, "IGNORE");
        }
    }

    public class MessageTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<string> stanza_id = new Column.Text("stanza_id");
        public Column<int> account_id = new Column.Integer("account_id") { not_null = true };
        public Column<int> counterpart_id = new Column.Integer("counterpart_id") { not_null = true };
        public Column<string> counterpart_resource = new Column.Text("counterpart_resource");
        public Column<string> our_resource = new Column.Text("our_resource");
        public Column<bool> direction = new Column.BoolInt("direction") { not_null = true };
        public Column<int> type_ = new Column.Integer("type");
        public Column<long> time = new Column.Long("time");
        public Column<long> local_time = new Column.Long("local_time");
        public Column<string> body = new Column.Text("body");
        public Column<int> encryption = new Column.Integer("encryption");
        public Column<int> marked = new Column.Integer("marked");

        internal MessageTable(Database db) {
            base(db, "message");
            init({id, stanza_id, account_id, counterpart_id, our_resource, counterpart_resource, direction,
                type_, time, local_time, body, encryption, marked});

            // get latest messages
            index("message_account_counterpart_localtime_idx", {account_id, counterpart_id, local_time});

            // deduplication
            index("message_account_counterpart_stanzaid_idx", {account_id, counterpart_id, stanza_id});
            fts({body});
        }
    }

    public class RealJidTable : Table {
        public Column<int> message_id = new Column.Integer("message_id") { primary_key = true };
        public Column<string> real_jid = new Column.Text("real_jid");

        internal RealJidTable(Database db) {
            base(db, "real_jid");
            init({message_id, real_jid});
        }
    }

    public class UndecryptedTable : Table {
        public Column<int> message_id = new Column.Integer("message_id");
        public Column<int> type_ = new Column.Integer("type");
        public Column<string> data = new Column.Text("data");

        internal UndecryptedTable(Database db) {
            base(db, "undecrypted");
            init({message_id, type_, data});
        }
    }

    public class FileTransferTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<int> account_id = new Column.Integer("account_id") { not_null = true };
        public Column<int> counterpart_id = new Column.Integer("counterpart_id") { not_null = true };
        public Column<string> counterpart_resource = new Column.Text("counterpart_resource");
        public Column<string> our_resource = new Column.Text("our_resource");
        public Column<bool> direction = new Column.BoolInt("direction") { not_null = true };
        public Column<long> time = new Column.Long("time");
        public Column<long> local_time = new Column.Long("local_time");
        public Column<int> encryption = new Column.Integer("encryption");
        public Column<string> file_name = new Column.Text("file_name");
        public Column<string> path = new Column.Text("path");
        public Column<string> mime_type = new Column.Text("mime_type");
        public Column<int> size = new Column.Integer("size");
        public Column<int> state = new Column.Integer("state");
        public Column<int> provider = new Column.Integer("provider");
        public Column<string> info = new Column.Text("info");

        internal FileTransferTable(Database db) {
            base(db, "file_transfer");
            init({id, account_id, counterpart_id, counterpart_resource, our_resource, direction, time, local_time,
                    encryption, file_name, path, mime_type, size, state, provider, info});
            index("filetransfer_localtime_counterpart_idx", {local_time, counterpart_id});
        }
    }

    public class ConversationTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<int> account_id = new Column.Integer("account_id") { not_null = true };
        public Column<int> jid_id = new Column.Integer("jid_id") { not_null = true };
        public Column<string> resource = new Column.Text("resource") { min_version=1 };
        public Column<bool> active = new Column.BoolInt("active");
        public Column<long> last_active = new Column.Long("last_active");
        public Column<int> type_ = new Column.Integer("type");
        public Column<int> encryption = new Column.Integer("encryption");
        public Column<int> read_up_to = new Column.Integer("read_up_to");
        public Column<int> notification = new Column.Integer("notification") { min_version=3 };
        public Column<int> send_typing = new Column.Integer("send_typing") { min_version=3 };
        public Column<int> send_marker = new Column.Integer("send_marker") { min_version=3 };

        internal ConversationTable(Database db) {
            base(db, "conversation");
            init({id, account_id, jid_id, resource, active, last_active, type_, encryption, read_up_to, notification, send_typing, send_marker});
        }
    }

    public class AvatarTable : Table {
        public Column<string> jid = new Column.Text("jid");
        public Column<string> hash = new Column.Text("hash");
        public Column<int> type_ = new Column.Integer("type");

        internal AvatarTable(Database db) {
            base(db, "avatar");
            init({jid, hash, type_});
        }
    }

    public class EntityFeatureTable : Table {
        public Column<string> entity = new Column.Text("entity");
        public Column<string> feature = new Column.Text("feature");

        internal EntityFeatureTable(Database db) {
            base(db, "entity_feature");
            init({entity, feature});
            unique({entity, feature}, "IGNORE");
            index("entity_feature_idx", {entity});
        }
    }

    public class RosterTable : Table {
        public Column<int> account_id = new Column.Integer("account_id");
        public Column<string> jid = new Column.Text("jid");
        public Column<string> handle = new Column.Text("name");
        public Column<string> subscription = new Column.Text("subscription");

        internal RosterTable(Database db) {
            base(db, "roster");
            init({account_id, jid, handle, subscription});
            unique({account_id, jid}, "IGNORE");
        }
    }

    public class SettingsTable : Table {
        public Column<int> id = new Column.Integer("id") { primary_key = true, auto_increment = true };
        public Column<string> key = new Column.Text("key") { unique = true, not_null = true };
        public Column<string> value = new Column.Text("value");

        internal SettingsTable(Database db) {
            base(db, "settings");
            init({id, key, value});
        }
    }

    public AccountTable account { get; private set; }
    public JidTable jid { get; private set; }
    public ContentItemTable content_item { get; private set; }
    public MessageTable message { get; private set; }
    public RealJidTable real_jid { get; private set; }
    public FileTransferTable file_transfer { get; private set; }
    public ConversationTable conversation { get; private set; }
    public AvatarTable avatar { get; private set; }
    public EntityFeatureTable entity_feature { get; private set; }
    public RosterTable roster { get; private set; }
    public SettingsTable settings { get; private set; }

    public Map<int, Jid> jid_table_cache = new HashMap<int, Jid>();
    public Map<Jid, int> jid_table_reverse = new HashMap<Jid, int>(Jid.hash_func, Jid.equals_func);
    public Map<int, Account> account_table_cache = new HashMap<int, Account>();

    public Database(string fileName) {
        base(fileName, VERSION);
        account = new AccountTable(this);
        jid = new JidTable(this);
        content_item = new ContentItemTable(this);
        message = new MessageTable(this);
        real_jid = new RealJidTable(this);
        file_transfer = new FileTransferTable(this);
        conversation = new ConversationTable(this);
        avatar = new AvatarTable(this);
        entity_feature = new EntityFeatureTable(this);
        roster = new RosterTable(this);
        settings = new SettingsTable(this);
        init({ account, jid, content_item, message, real_jid, file_transfer, conversation, avatar, entity_feature, roster, settings });
        try {
            exec("PRAGMA synchronous=0");
        } catch (Error e) { }
    }

    public override void migrate(long oldVersion) {
        // new table columns are added, outdated columns are still present
        if (oldVersion < 7) {
            message.fts_rebuild();
        }
        if (oldVersion < 8) {
            try {
                exec("""
                insert into content_item (conversation_id, time, local_time, content_type, foreign_id, hide)
                select conversation.id, message.time, message.local_time, 1, message.id, 0
                from message join conversation on
                    message.account_id=conversation.account_id and
                    message.counterpart_id=conversation.jid_id and
                    message.type=conversation.type+1 and
                    (message.counterpart_resource=conversation.resource or message.type != 3)
                where
                    message.body not in (select info from file_transfer where info not null) and
                    message.id not in (select info from file_transfer where info not null)
                union
                select conversation.id, message.time, message.local_time, 2, file_transfer.id, 0
                from file_transfer
                join message on
                    file_transfer.info=message.id
                join conversation on
                    file_transfer.account_id=conversation.account_id and
                    file_transfer.counterpart_id=conversation.jid_id and
                    message.type=conversation.type+1 and
                    (message.counterpart_resource=conversation.resource or message.type != 3)""");
            } catch (Error e) {
                error("Failed to upgrade to database version 8: %s", e.message);
            }
        }
        if (oldVersion < 9) {
            try {
                exec("""
                insert into content_item (conversation_id, time, local_time, content_type, foreign_id, hide)
                select conversation.id, message.time, message.local_time, 1, message.id, 1
                from message join conversation on
                    message.account_id=conversation.account_id and
                    message.counterpart_id=conversation.jid_id and
                    message.type=conversation.type+1 and
                    (message.counterpart_resource=conversation.resource or message.type != 3)
                where
                    message.body in (select info from file_transfer where info not null) or
                    message.id in (select info from file_transfer where info not null)""");
            } catch (Error e) {
                error("Failed to upgrade to database version 9: %s", e.message);
            }
        }
    }

    public ArrayList<Account> get_accounts() {
        ArrayList<Account> ret = new ArrayList<Account>(Account.equals_func);
        foreach(Row row in account.select()) {
            Account account = new Account.from_row(this, row);
            ret.add(account);
            account_table_cache[account.id] = account;
        }
        return ret;
    }

    public Account? get_account_by_id(int id) {
        if (account_table_cache.has_key(id)) {
            return account_table_cache[id];
        } else {
            Row? row = account.row_with(account.id, id).inner;
            if (row != null) {
                Account a = new Account.from_row(this, row);
                account_table_cache[a.id] = a;
                return a;
            }
            return null;
        }
    }

    public int add_content_item(Conversation conversation, DateTime time, DateTime local_time, int content_type, int foreign_id, bool hide) {
        return (int) content_item.insert()
            .value(content_item.conversation_id, conversation.id)
            .value(content_item.local_time, (long) local_time.to_unix())
            .value(content_item.time, (long) time.to_unix())
            .value(content_item.content_type, content_type)
            .value(content_item.foreign_id, foreign_id)
            .value(content_item.hide, hide)
            .perform();
    }

    public Gee.List<Message> get_messages(Jid jid, Account account, Message.Type? type, int count, DateTime? before, DateTime? after, int id) {
        QueryBuilder select = message.select();

        if (before != null) {
            if (id > 0) {
                select.where(@"local_time < ? OR (local_time = ? AND id < ?)", { before.to_unix().to_string(), before.to_unix().to_string(), id.to_string() });
            } else {
                select.with(message.id, "<", id);
            }
        }
        if (after != null) {
            if (id > 0) {
                select.where(@"local_time > ? OR (local_time = ? AND id > ?)", { after.to_unix().to_string(), after.to_unix().to_string(), id.to_string() });
            } else {
                select.with(message.local_time, ">", (long) after.to_unix());
            }
            if (id > 0) {
                select.with(message.id, ">", id);
            }
        } else {
            select.order_by(message.local_time, "DESC");
        }

        select.with(message.counterpart_id, "=", get_jid_id(jid))
                .with(message.account_id, "=", account.id)
                .limit(count);
        if (jid.resourcepart != null) {
            select.with(message.counterpart_resource, "=", jid.resourcepart);
        }
        if (type != null) {
            select.with(message.type_, "=", (int) type);
        }

        select.outer_join_with(real_jid, real_jid.message_id, message.id);

        LinkedList<Message> ret = new LinkedList<Message>();
        foreach (Row row in select) {
            ret.insert(0, new Message.from_row(this, row));
        }
        return ret;
    }

    public Gee.List<Message> get_unsend_messages(Account account, Jid? jid = null) {
        Gee.List<Message> ret = new ArrayList<Message>();
        var select = message.select()
            .with(message.account_id, "=", account.id)
            .with(message.marked, "=", (int) Message.Marked.UNSENT);
        if (jid != null) {
            select.with(message.counterpart_id, "=", get_jid_id(jid));
        }
        foreach (Row row in select) {
            ret.add(new Message.from_row(this, row));
        }
        return ret;
    }

    public bool contains_message(Message query_message, Account account) {
        QueryBuilder builder = message.select()
                .with(message.account_id, "=", account.id)
                .with(message.counterpart_id, "=", get_jid_id(query_message.counterpart))
                .with(message.body, "=", query_message.body)
                .with(message.time, "<", (long) query_message.time.add_minutes(1).to_unix())
                .with(message.time, ">", (long) query_message.time.add_minutes(-1).to_unix());
        if (query_message.stanza_id != null) {
            builder.with(message.stanza_id, "=", query_message.stanza_id);
        } else {
            builder.with_null(message.stanza_id);
        }
        if (query_message.counterpart.resourcepart != null) {
            builder.with(message.counterpart_resource, "=", query_message.counterpart.resourcepart);
        } else {
            builder.with_null(message.counterpart_resource);
        }
        return builder.count() > 0;
    }

    public bool contains_message_by_stanza_id(Message query_message, Account account) {
        QueryBuilder builder =  message.select()
                .with(message.stanza_id, "=", query_message.stanza_id)
                .with(message.counterpart_id, "=", get_jid_id(query_message.counterpart))
                .with(message.account_id, "=", account.id);
        if (query_message.counterpart.resourcepart != null) {
            builder.with(message.counterpart_resource, "=", query_message.counterpart.resourcepart);
        } else {
            builder.with_null(message.counterpart_resource);
        }
        return builder.count() > 0;
    }

    public Message? get_message_by_id(int id) {
        Row? row = message.row_with(message.id, id).inner;
        if (row != null) {
            return new Message.from_row(this, row);
        }
        return null;
    }

    public ArrayList<Conversation> get_conversations(Account account) {
        ArrayList<Conversation> ret = new ArrayList<Conversation>();
        foreach (Row row in conversation.select().with(conversation.account_id, "=", account.id)) {
            ret.add(new Conversation.from_row(this, row));
        }
        return ret;
    }

    public void set_avatar_hash(Jid jid, string hash, int type) {
        avatar.insert().or("REPLACE")
                .value(avatar.jid, jid.to_string())
                .value(avatar.hash, hash)
                .value(avatar.type_, type)
                .perform();
    }

    public HashMap<Jid, string> get_avatar_hashes(int type) {
        HashMap<Jid, string> ret = new HashMap<Jid, string>(Jid.hash_func, Jid.equals_func);
        foreach (Row row in avatar.select({avatar.jid, avatar.hash}).with(avatar.type_, "=", type)) {
            ret[Jid.parse(row[avatar.jid])] = row[avatar.hash];
        }
        return ret;
    }

    public void add_entity_features(string entity, Gee.List<string> features) {
        foreach (string feature in features) {
            entity_feature.insert()
                    .value(entity_feature.entity, entity)
                    .value(entity_feature.feature, feature)
                    .perform();
        }
    }

    public Gee.List<string> get_entity_features(string entity) {
        ArrayList<string> ret = new ArrayList<string>();
        foreach (Row row in entity_feature.select({entity_feature.feature}).with(entity_feature.entity, "=", entity)) {
            ret.add(row[entity_feature.feature]);
        }
        return ret;
    }


    public int get_jid_id(Jid jid_obj) {
        var bare_jid = jid_obj.bare_jid;
        if (jid_table_reverse.has_key(bare_jid)) {
            return jid_table_reverse[bare_jid];
        } else {
            Row? row = jid.row_with(jid.bare_jid, jid_obj.bare_jid.to_string()).inner;
            if (row != null) {
                int id = row[jid.id];
                jid_table_cache[id] = bare_jid;
                jid_table_reverse[bare_jid] = id;
                return id;
            } else {
                return add_jid(jid_obj);
            }
        }
    }

    public Jid? get_jid_by_id(int id) {
        if (jid_table_cache.has_key(id)) {
            return jid_table_cache[id];
        } else {
            string? bare_jid = jid.select({jid.bare_jid}).with(jid.id, "=", id)[jid.bare_jid];
            if (bare_jid != null) {
                Jid jid_parsed = Jid.parse(bare_jid);
                jid_table_cache[id] = jid_parsed;
                jid_table_reverse[jid_parsed] = id;
                return jid_parsed;
            }
            return null;
        }
    }

    private int add_jid(Jid jid_obj) {
        Jid bare_jid = jid_obj.bare_jid;
        int id = (int) jid.insert().value(jid.bare_jid, bare_jid.to_string()).perform();
        jid_table_cache[id] = bare_jid;
        jid_table_reverse[bare_jid] = id;
        return id;
    }
}

}
