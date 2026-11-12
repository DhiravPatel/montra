package communities

import (
	"context"
	"regexp"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/database"
)

// mentionRe finds @username mentions (usernames are [a-z0-9_.]{3,30}); an
// @ inside a word or e-mail address is not a mention.
var mentionRe = regexp.MustCompile(`(?:^|[^A-Za-z0-9_.@])@([A-Za-z0-9_.]{3,30})`)

// maxMentions bounds notifications from one post or comment (anti-spam).
const maxMentions = 10

// Mentions returns the distinct usernames mentioned in text, in order.
func Mentions(text string) []string {
	seen := map[string]bool{}
	var out []string
	for _, m := range mentionRe.FindAllStringSubmatch(text, -1) {
		u := strings.TrimRight(strings.ToLower(m[1]), ".")
		if len(u) < 3 || seen[u] {
			continue
		}
		seen[u] = true
		out = append(out, u)
		if len(out) == maxMentions {
			break
		}
	}
	return out
}

// notifyMentions tells active members mentioned in a published post or
// comment, except the author, people with a block either way, people who
// muted the author, and (for comments) those already told about the
// comment as post or parent author.
func notifyMentions(ctx context.Context, tx pgx.Tx, kind string, id uuid.UUID) error {
	var commID, postID uuid.UUID
	var author *uuid.UUID
	var text, status string
	var skip []uuid.UUID
	var err error
	switch kind {
	case "post":
		err = tx.QueryRow(ctx, `select community_id, id, author_id, title || ' ' || body, status from community_posts where id = $1`, id).
			Scan(&commID, &postID, &author, &text, &status)
	case "comment":
		var postAuthor, parentAuthor *uuid.UUID
		err = tx.QueryRow(ctx, `select c.community_id, c.post_id, c.author_id, c.body, c.status, p.author_id, pc.author_id
			from community_comments c join community_posts p on p.id = c.post_id
			left join community_comments pc on pc.id = c.parent_comment_id where c.id = $1`, id).
			Scan(&commID, &postID, &author, &text, &status, &postAuthor, &parentAuthor)
		for _, u := range []*uuid.UUID{postAuthor, parentAuthor} {
			if u != nil {
				skip = append(skip, *u)
			}
		}
	default:
		return nil
	}
	if database.IsNoRows(err) || (err == nil && (status != "published" || author == nil)) {
		return nil
	}
	if err != nil {
		return err
	}
	names := Mentions(text)
	if len(names) == 0 {
		return nil
	}
	skip = append(skip, *author)
	rows, err := tx.Query(ctx, `select p.user_id from profiles p
		join community_members m on m.user_id = p.user_id and m.community_id = $1 and m.status = 'active'
		join users u on u.id = p.user_id and u.status = 'active'
		where p.username = any($2) and not (p.user_id = any($3))
		and not montra.is_blocked_between($4, p.user_id)
		and not exists (select 1 from user_mutes mu where mu.muter_id = p.user_id and mu.muted_id = $4)`, commID, names, skip, *author)
	if err != nil {
		return err
	}
	targets, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return err
	}
	pid := postID
	for _, uid := range targets {
		if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "community", EventType: "mention",
			Title: "You were mentioned in a community " + kind, Body: "Open the community to read it.", DeepLink: "/posts/" + pid.String(),
			EntityType: "community_post", EntityID: &pid, DedupeKey: "community_mention:" + kind + ":" + id.String() + ":" + uid.String()}); err != nil {
			return err
		}
	}
	return nil
}
