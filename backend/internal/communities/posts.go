package communities

import (
	"context"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"montra/backend/internal/domain/textsafe"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// Spam controls (spec §20B.17). New accounts get tighter limits.
const (
	maxPostsPerDay        = 20
	maxCommentsPerDay     = 300
	newAccountPostsPerDay = 3
	newAccountComments    = 30
	maxBodyLinks          = 3
)

// CommunityAuthorDTO is the minimal public identity of a content author.
type CommunityAuthorDTO struct {
	UserID       *uuid.UUID `json:"user_id,omitempty" doc:"Absent when the author deleted their account"`
	DisplayName  string     `json:"display_name"`
	Username     *string    `json:"username,omitempty"`
	AvatarFileID *uuid.UUID `json:"avatar_file_id,omitempty"`
}

// CommunityPollInput creates a poll with a post.
type CommunityPollInput struct {
	Question      string     `json:"question" minLength:"3" maxLength:"300"`
	Options       []string   `json:"options" minItems:"2" maxItems:"10"`
	AllowMultiple bool       `json:"allow_multiple,omitempty"`
	ClosesAt      *time.Time `json:"closes_at,omitempty"`
}

// CommunityPostInput creates or edits a post.
type CommunityPostInput struct {
	Kind    string              `json:"kind,omitempty" enum:"discussion,question,resource,poll" doc:"Default discussion"`
	Label   string              `json:"label,omitempty" enum:"personal_experience,verified_guidance,question,resource" doc:"verified_guidance is reserved for moderators; default personal_experience"`
	Title   string              `json:"title" minLength:"3" maxLength:"200"`
	Body    string              `json:"body,omitempty" maxLength:"10000" doc:"Plain text; rendered escaped"`
	LinkURL string              `json:"link_url,omitempty" maxLength:"500" doc:"Public https link for resource posts"`
	Poll    *CommunityPollInput `json:"poll,omitempty"`
}

// CommunityPollOptionDTO is a poll option with its vote count.
type CommunityPollOptionDTO struct {
	ID    uuid.UUID `json:"id"`
	Label string    `json:"label"`
	Votes int       `json:"votes"`
}

// CommunityPollDTO is a poll with aggregate results (individual votes are private).
type CommunityPollDTO struct {
	ID            uuid.UUID                `json:"id"`
	Question      string                   `json:"question"`
	AllowMultiple bool                     `json:"allow_multiple"`
	ClosesAt      *time.Time               `json:"closes_at,omitempty"`
	Closed        bool                     `json:"closed"`
	Options       []CommunityPollOptionDTO `json:"options"`
	TotalVotes    int                      `json:"total_votes"`
	MyVotes       []uuid.UUID              `json:"my_votes"`
}

// CommunityReactionCounts counts reactions by kind.
type CommunityReactionCounts struct {
	Like       int `json:"like"`
	Helpful    int `json:"helpful"`
	Insightful int `json:"insightful"`
	Support    int `json:"support"`
}

// CommunityReactionsDTO is the state of reactions after adding or removing
// one: the counts and the kinds the caller reacted with.
type CommunityReactionsDTO struct {
	CommunityReactionCounts
	MyReactions []string `json:"my_reactions"`
}

// CommunityPostDTO is a post.
type CommunityPostDTO struct {
	ID            uuid.UUID               `json:"id"`
	CommunityID   uuid.UUID               `json:"community_id"`
	Author        CommunityAuthorDTO      `json:"author"`
	Kind          string                  `json:"kind" enum:"discussion,question,resource,poll,challenge_update"`
	Label         string                  `json:"label" enum:"personal_experience,verified_guidance,question,resource" doc:"verified_guidance is set only by moderators"`
	Title         string                  `json:"title"`
	Body          string                  `json:"body"`
	LinkURL       *string                 `json:"link_url,omitempty"`
	Status        string                  `json:"status" enum:"published,hidden,removed,deleted"`
	RemovedReason *string                 `json:"removed_reason,omitempty" doc:"Shown to the author and moderators"`
	Pinned        bool                    `json:"pinned"`
	Locked        bool                    `json:"locked"`
	CommentCount  int                     `json:"comment_count"`
	Reactions     CommunityReactionCounts `json:"reactions"`
	MyReactions   []string                `json:"my_reactions"`
	Poll          *CommunityPollDTO       `json:"poll,omitempty"`
	Mine          bool                    `json:"mine"`
	EditedAt      *time.Time              `json:"edited_at,omitempty"`
	CreatedAt     time.Time               `json:"created_at"`
}

// CommunityCommentDTO is a comment or reply.
type CommunityCommentDTO struct {
	ID              uuid.UUID               `json:"id"`
	PostID          uuid.UUID               `json:"post_id"`
	ParentCommentID *uuid.UUID              `json:"parent_comment_id,omitempty"`
	Author          CommunityAuthorDTO      `json:"author"`
	Body            string                  `json:"body" doc:"Empty when removed or deleted"`
	Status          string                  `json:"status" enum:"published,hidden,removed,deleted"`
	Reactions       CommunityReactionCounts `json:"reactions"`
	MyReactions     []string                `json:"my_reactions"`
	Mine            bool                    `json:"mine"`
	EditedAt        *time.Time              `json:"edited_at,omitempty"`
	CreatedAt       time.Time               `json:"created_at"`
}

// CommunityPostDetail is a post with its comments (flat, oldest first; replies
// carry parent_comment_id).
type CommunityPostDetail struct {
	CommunityPostDTO
	Comments []CommunityCommentDTO `json:"comments"`
}

func author(ctx context.Context, tx pgx.Tx, communityID uuid.UUID, id *uuid.UUID) CommunityAuthorDTO {
	a := CommunityAuthorDTO{UserID: id, DisplayName: "Former member"}
	if id == nil {
		return a
	}
	_ = tx.QueryRow(ctx, `select display_name, username, avatar_file_id from montra.community_member_profile($1, $2)`, communityID, *id).
		Scan(&a.DisplayName, &a.Username, &a.AvatarFileID)
	return a
}

func reactions(ctx context.Context, tx pgx.Tx, me uuid.UUID, postID, commentID *uuid.UUID) (CommunityReactionCounts, []string, error) {
	var rc CommunityReactionCounts
	mine := []string{}
	rows, err := tx.Query(ctx, `select kind, count(*)::int, bool_or(user_id = $3) from community_reactions
		where ($1::uuid is not null and post_id = $1) or ($2::uuid is not null and comment_id = $2) group by kind`, postID, commentID, me)
	if err != nil {
		return rc, nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var k string
		var n int
		var my bool
		if err := rows.Scan(&k, &n, &my); err != nil {
			return rc, nil, err
		}
		switch k {
		case "like":
			rc.Like = n
		case "helpful":
			rc.Helpful = n
		case "insightful":
			rc.Insightful = n
		case "support":
			rc.Support = n
		}
		if my {
			mine = append(mine, k)
		}
	}
	return rc, mine, rows.Err()
}

const postCols = `p.id, p.community_id, p.author_id, p.kind, p.label, p.title, p.body, p.link_url, p.status, p.removed_reason, p.pinned, p.locked,
	p.edited_at, p.created_at, (select count(*)::int from community_comments c where c.post_id = p.id and c.status = 'published')`

// scanPosts reads posts from a query selecting postCols, optionally
// followed by a feed sort key (returned alongside, for cursors).
func (s *Service) scanPosts(ctx context.Context, tx pgx.Tx, me uuid.UUID, rows pgx.Rows) ([]CommunityPostDTO, []feedKey, error) {
	type raw struct {
		p      CommunityPostDTO
		author *uuid.UUID
		key    feedKey
	}
	withKey := len(rows.FieldDescriptions()) > 15
	var list []raw
	for rows.Next() {
		var x raw
		dest := []any{&x.p.ID, &x.p.CommunityID, &x.author, &x.p.Kind, &x.p.Label, &x.p.Title, &x.p.Body, &x.p.LinkURL, &x.p.Status,
			&x.p.RemovedReason, &x.p.Pinned, &x.p.Locked, &x.p.EditedAt, &x.p.CreatedAt, &x.p.CommentCount}
		if withKey {
			if rows.FieldDescriptions()[15].DataTypeOID == pgtype.Int8OID {
				dest = append(dest, &x.key.count)
			} else {
				dest = append(dest, &x.key.at)
			}
		}
		if err := rows.Scan(dest...); err != nil {
			rows.Close()
			return nil, nil, err
		}
		list = append(list, x)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}
	out := make([]CommunityPostDTO, 0, len(list))
	keys := make([]feedKey, 0, len(list))
	mods := map[uuid.UUID]bool{}
	for _, x := range list {
		p := x.p
		p.Author = author(ctx, tx, p.CommunityID, x.author)
		p.Mine = x.author != nil && *x.author == me
		if p.Status == "removed" || p.Status == "deleted" {
			p.Body, p.LinkURL = "", nil
		}
		if !p.Mine {
			mod, ok := mods[p.CommunityID]
			if !ok {
				var err error
				if mod, err = isModerator(ctx, tx, p.CommunityID); err != nil {
					return nil, nil, err
				}
				mods[p.CommunityID] = mod
			}
			if !mod {
				p.RemovedReason = nil
			}
		}
		id := p.ID
		var err error
		if p.Reactions, p.MyReactions, err = reactions(ctx, tx, me, &id, nil); err != nil {
			return nil, nil, err
		}
		if p.Kind == "poll" {
			if p.Poll, err = s.poll(ctx, tx, me, p.ID); err != nil {
				return nil, nil, err
			}
		}
		out = append(out, p)
		keys = append(keys, x.key)
	}
	return out, keys, nil
}

func (s *Service) poll(ctx context.Context, tx pgx.Tx, me, postID uuid.UUID) (*CommunityPollDTO, error) {
	var p CommunityPollDTO
	err := tx.QueryRow(ctx, `select id, question, allow_multiple, closes_at from community_polls where post_id = $1`, postID).
		Scan(&p.ID, &p.Question, &p.AllowMultiple, &p.ClosesAt)
	if database.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	p.Closed = p.ClosesAt != nil && !p.ClosesAt.After(s.now())
	rows, err := tx.Query(ctx, `select o.id, o.label, coalesce(r.votes, 0)::int from community_poll_options o
		left join montra.poll_results($1) r on r.option_id = o.id where o.poll_id = $1 order by o.position`, p.ID)
	if err != nil {
		return nil, err
	}
	if p.Options, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (CommunityPollOptionDTO, error) {
		var o CommunityPollOptionDTO
		err := r.Scan(&o.ID, &o.Label, &o.Votes)
		return o, err
	}); err != nil {
		return nil, err
	}
	for _, o := range p.Options {
		p.TotalVotes += o.Votes
	}
	vrows, err := tx.Query(ctx, `select option_id from community_poll_votes where poll_id = $1 and user_id = $2`, p.ID, me)
	if err != nil {
		return nil, err
	}
	if p.MyVotes, err = pgx.CollectRows(vrows, pgx.RowTo[uuid.UUID]); err != nil {
		return nil, err
	}
	if p.MyVotes == nil {
		p.MyVotes = []uuid.UUID{}
	}
	return &p, nil
}

// spamCheck applies the rolling daily caps (tighter for accounts younger
// than a day): 429 RATE_LIMITED with Retry-After and detail code daily_cap.
func spamCheck(ctx context.Context, tx pgx.Tx, uid uuid.UUID, posts bool) error {
	var young bool
	if err := tx.QueryRow(ctx, `select created_at > now() - interval '1 day' from users where id = $1`, uid).Scan(&young); err != nil {
		return err
	}
	resource, times := "comments", `select created_at from community_comments where author_id = $1 and created_at > now() - interval '1 day'`
	limit := maxCommentsPerDay
	if young {
		limit = newAccountComments
	}
	if posts {
		resource, times = "posts", `select created_at from community_posts where author_id = $1 and created_at > now() - interval '1 day'`
		limit = maxPostsPerDay
		if young {
			limit = newAccountPostsPerDay
		}
	}
	return caps.Daily(ctx, tx, uid, resource, times, limit)
}

// tooManyLinks refuses text with more than maxBodyLinks links.
func tooManyLinks(what string) error {
	return apperr.FieldCode("body.body", textsafe.CodeTooManyLinks, "Use at most "+strconv.Itoa(maxBodyLinks)+" links in a "+what+".",
		map[string]string{"max": strconv.Itoa(maxBodyLinks)})
}

func (s *Service) validatePost(in *CommunityPostInput, moderator bool) (title string, body string, link *string, err error) {
	t, err := cleanField("body.title", in.Title, 3, 200)
	if err != nil {
		return "", "", nil, err
	}
	b, err := cleanField("body.body", in.Body, 0, 10000)
	if err != nil {
		return "", "", nil, err
	}
	if b != nil {
		body = *b
	}
	if textsafe.Links(body) > maxBodyLinks {
		return "", "", nil, tooManyLinks("post")
	}
	if in.LinkURL != "" {
		l, lerr := textsafe.Link(in.LinkURL)
		if lerr != nil {
			return "", "", nil, apperr.FieldCode("body.link_url", textsafe.CodeInsecureLink, "Use a public https link.", nil)
		}
		link = &l
	}
	if in.Kind == "" {
		in.Kind = "discussion"
	}
	if in.Label == "" {
		in.Label = map[string]string{"question": "question", "resource": "resource"}[in.Kind]
		if in.Label == "" {
			in.Label = "personal_experience"
		}
	}
	if in.Label == "verified_guidance" && !moderator {
		return "", "", nil, apperr.FieldCode("body.label", "moderators_only", "Only moderators can mark a post as verified guidance.", nil)
	}
	if in.Kind == "resource" && link == nil {
		return "", "", nil, apperr.FieldCode("body.link_url", "link_required", "Resource posts need a link.", nil)
	}
	if (in.Kind == "poll") != (in.Poll != nil) {
		return "", "", nil, apperr.FieldCode("body.poll", "poll_mismatch", "Poll posts need a poll, and only poll posts have one.", nil)
	}
	return *t, body, link, nil
}

// CreatePost publishes a post (active members).
func (s *Service) CreatePost(ctx context.Context, communityID uuid.UUID, in CommunityPostInput) (*CommunityPostDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityPostDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := loadCommunity(ctx, tx, uid, communityID)
		if err != nil {
			return err
		}
		if err := s.requireParticipant(ctx, tx, c); err != nil {
			return err
		}
		mod, err := isModerator(ctx, tx, communityID)
		if err != nil {
			return err
		}
		title, body, link, err := s.validatePost(&in, mod)
		if err != nil {
			return err
		}
		if err := spamCheck(ctx, tx, uid, true); err != nil {
			return err
		}
		var young bool
		if err := tx.QueryRow(ctx, `select created_at > now() - interval '1 day' from users where id = $1`, uid).Scan(&young); err != nil {
			return err
		}
		if young && (link != nil || textsafe.Links(body) > 0) {
			return apperr.Rule("new_account_links", "New accounts can share links after their first day.", nil)
		}
		var dup bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from community_posts where author_id = $1 and community_id = $2 and lower(title) = lower($3)
			and created_at > now() - interval '1 day' and status <> 'deleted')`, uid, communityID, title).Scan(&dup); err != nil {
			return err
		}
		if dup {
			return apperr.Conflict("You already posted this here today.")
		}
		var poll []string
		var question *string
		if in.Poll != nil {
			q, err := cleanField("body.poll.question", in.Poll.Question, 3, 300)
			if err != nil {
				return err
			}
			question = q
			seen := map[string]bool{}
			for _, o := range in.Poll.Options {
				l, err := cleanField("body.poll.options", o, 1, 120)
				if err != nil {
					return err
				}
				if seen[strings.ToLower(*l)] {
					return apperr.FieldCode("body.poll.options", "duplicate_option", "Poll options must be different.", nil)
				}
				seen[strings.ToLower(*l)] = true
				poll = append(poll, *l)
			}
			if len(poll) < 2 {
				return apperr.FieldCode("body.poll.options", "too_few", "Give at least two options.", map[string]string{"min": "2"})
			}
			if in.Poll.ClosesAt != nil && !in.Poll.ClosesAt.After(s.now()) {
				return apperr.FieldCode("body.poll.closes_at", "must_be_future", "The closing time must be in the future.", nil)
			}
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into community_posts (id, community_id, author_id, kind, label, title, body, link_url) values ($1,$2,$3,$4,$5,$6,$7,$8)`,
			id, communityID, uid, in.Kind, in.Label, title, body, link); err != nil {
			return err
		}
		if in.Poll != nil {
			pid := uuid.New()
			if _, err := tx.Exec(ctx, `insert into community_polls (id, post_id, community_id, question, allow_multiple, closes_at) values ($1,$2,$3,$4,$5,$6)`,
				pid, id, communityID, *question, in.Poll.AllowMultiple, in.Poll.ClosesAt); err != nil {
				return err
			}
			for i, o := range poll {
				if _, err := tx.Exec(ctx, `insert into community_poll_options (poll_id, community_id, position, label) values ($1,$2,$3,$4)`,
					pid, communityID, i+1, o); err != nil {
					return err
				}
			}
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventPostCreated, AggregateType: "community_post", AggregateID: id, UserID: &uid}); err != nil {
			return err
		}
		out, err = s.post(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

func (s *Service) post(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*CommunityPostDTO, error) {
	rows, err := tx.Query(ctx, `select `+postCols+` from community_posts p where p.id = $1
		and (p.author_id is null or p.author_id = $2 or not montra.is_blocked_between($2, p.author_id))`, id, me)
	if err != nil {
		return nil, err
	}
	list, _, err := s.scanPosts(ctx, tx, me, rows)
	if err != nil {
		return nil, err
	}
	if len(list) == 0 {
		return nil, apperr.NotFound("post")
	}
	return &list[0], nil
}

// feedCursor is a position in a feed: pinned posts first, then the sort
// key (reaction count for top, latest activity for active, creation time
// for new), newest first, with the post's creation time and ID as
// tie-breakers. A cursor only continues the sort it was made for.
type feedCursor struct {
	Sort      string    `json:"s"`
	Pinned    bool      `json:"p"`
	Count     int64     `json:"n"`
	At        time.Time `json:"a"`
	CreatedAt time.Time `json:"c"`
	ID        uuid.UUID `json:"i"`
}

// feedSorts maps a sort to the expression of its key (alias p).
var feedSorts = map[string]string{
	"new":    `p.created_at`,
	"top":    `(select count(*) from community_reactions r where r.post_id = p.id)`,
	"active": `coalesce((select max(c.created_at) from community_comments c where c.post_id = p.id and c.status = 'published'), p.created_at)`,
}

// Feed lists a community's posts, a page at a time. sort: new (default),
// top (most reactions), active (latest comment). Pinned posts come first.
// Posts by people the caller blocked (or who blocked them) are hidden.
// cursor continues an earlier page (offset is kept for older clients). It
// returns the next page's cursor ("" on the last page).
func (s *Service) Feed(ctx context.Context, communityID uuid.UUID, sort, q, cursor string, limit, offset int) ([]CommunityPostDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	if sort == "" {
		sort = "new"
	}
	key, ok := feedSorts[sort]
	if !ok {
		return nil, "", apperr.FieldCode("query.sort", "invalid_choice", "Sort by new, top or active.", map[string]string{"allowed": "new, top, active"})
	}
	var cur feedCursor
	if err := httpx.DecodeCursor(cursor, &cur); err != nil {
		return nil, "", err
	}
	if cursor != "" && cur.Sort != sort {
		return nil, "", apperr.FieldError("query.cursor", "Invalid cursor. Start again from the first page.")
	}
	// The position's key ($7) is a timestamp (new, active) or a count
	// (top); without a cursor $6 is null and the position is not applied.
	keyType, keyArg := "timestamptz", any(cur.At)
	if sort == "top" {
		keyType, keyArg = "bigint", any(cur.Count)
	}
	var pinned *int
	if cursor != "" {
		offset = 0
		p := 0
		if cur.Pinned {
			p = 1
		}
		pinned = &p
	}
	var out []CommunityPostDTO
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := loadCommunity(ctx, tx, uid, communityID); err != nil {
			return err
		}
		var ok bool
		if err := tx.QueryRow(ctx, `select montra.can_view_community_content($1)`, communityID).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.Forbidden()
		}
		rows, err := tx.Query(ctx, `select `+postCols+`, p.k from (select p.*, `+key+` as k from community_posts p
			where p.community_id = $1 and p.status <> 'deleted' and (p.status = 'published' or p.author_id = $2 or montra.is_community_moderator($1))
			and (p.author_id is null or not montra.is_blocked_between($2, p.author_id))
			and ($3 = '' or p.title ilike '%' || $3 || '%' or p.body ilike '%' || $3 || '%')) p
			where ($6::int is null or (p.pinned::int, p.k, p.created_at, p.id) < ($6::int, $7::`+keyType+`, $8::timestamptz, $9::uuid))
			order by p.pinned desc, p.k desc, p.created_at desc, p.id desc limit $4 offset $5`,
			communityID, uid, likeEscape(strings.TrimSpace(q)), limit+1, min(max(offset, 0), 1000), pinned, keyArg, cur.CreatedAt, cur.ID)
		if err != nil {
			return err
		}
		var keys []feedKey
		if out, keys, err = s.scanPosts(ctx, tx, uid, rows); err != nil {
			return err
		}
		if len(out) > limit {
			last, k := out[limit-1], keys[limit-1]
			if next, err = httpx.EncodeCursor(feedCursor{Sort: sort, Pinned: last.Pinned, Count: k.count, At: k.at, CreatedAt: last.CreatedAt, ID: last.ID}); err != nil {
				return err
			}
			out = out[:limit]
		}
		return nil
	})
	return out, next, database.MapError(err)
}

// feedKey is a post's sort key as scanned from a feed query (count for
// top, a time otherwise).
type feedKey struct {
	count int64
	at    time.Time
}

// GetPost returns a post with its comments.
func (s *Service) GetPost(ctx context.Context, id uuid.UUID) (*CommunityPostDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out CommunityPostDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		p, err := s.post(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		out.CommunityPostDTO = *p
		out.Comments, err = s.comments(ctx, tx, uid, p.CommunityID, id)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// comments lists a post's comments. Hidden comments reach only their
// author and the community's moderators (RLS); their text is shown to
// those people so they can review it. Removed and deleted comments have no
// text for anyone.
func (s *Service) comments(ctx context.Context, tx pgx.Tx, me, communityID, postID uuid.UUID) ([]CommunityCommentDTO, error) {
	rows, err := tx.Query(ctx, `select c.id, c.post_id, c.parent_comment_id, c.author_id, c.body, c.status, c.edited_at, c.created_at
		from community_comments c where c.post_id = $1 and (c.author_id is null or not montra.is_blocked_between($2, c.author_id))
		order by c.created_at limit 1000`, postID, me)
	if err != nil {
		return nil, err
	}
	type raw struct {
		c      CommunityCommentDTO
		author *uuid.UUID
	}
	list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (raw, error) {
		var x raw
		err := r.Scan(&x.c.ID, &x.c.PostID, &x.c.ParentCommentID, &x.author, &x.c.Body, &x.c.Status, &x.c.EditedAt, &x.c.CreatedAt)
		return x, err
	})
	if err != nil {
		return nil, err
	}
	mod, err := isModerator(ctx, tx, communityID)
	if err != nil {
		return nil, err
	}
	out := make([]CommunityCommentDTO, 0, len(list))
	for _, x := range list {
		c := x.c
		c.Author, c.Mine = author(ctx, tx, communityID, x.author), x.author != nil && *x.author == me
		if c.Status != "published" && (c.Status != "hidden" || (!c.Mine && !mod)) {
			c.Body = ""
		}
		id := c.ID
		if c.Reactions, c.MyReactions, err = reactions(ctx, tx, me, nil, &id); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, nil
}

// lockPost loads a post the caller can see, with its community.
func (s *Service) lockPost(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (*CommunityPostDTO, *CommunityDTO, error) {
	p, err := s.post(ctx, tx, uid, id)
	if err != nil {
		return nil, nil, err
	}
	c, err := loadCommunity(ctx, tx, uid, p.CommunityID)
	if err != nil {
		return nil, nil, err
	}
	return p, c, nil
}

// UpdatePost edits the author's own post.
func (s *Service) UpdatePost(ctx context.Context, id uuid.UUID, in CommunityPostInput) (*CommunityPostDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityPostDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		p, c, err := s.lockPost(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if !p.Mine {
			return apperr.Forbidden()
		}
		if p.Status != "published" {
			return apperr.Rule("post_locked", "This post can no longer be edited.", nil)
		}
		if err := s.requireParticipant(ctx, tx, c); err != nil {
			return err
		}
		mod, err := isModerator(ctx, tx, p.CommunityID)
		if err != nil {
			return err
		}
		in.Kind = p.Kind
		if in.Kind == "poll" && in.Poll == nil {
			in.Poll = &CommunityPollInput{} // the existing poll stays as it is
		}
		title, body, link, err := s.validatePost(&in, mod)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update community_posts set title = $2, body = $3, link_url = $4, label = $5, edited_at = now() where id = $1`,
			id, title, body, link, in.Label); err != nil {
			return err
		}
		out, err = s.post(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// DeletePost deletes the author's own post (content is cleared).
func (s *Service) DeletePost(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		p, _, err := s.lockPost(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if !p.Mine {
			return apperr.Forbidden()
		}
		_, err = tx.Exec(ctx, `update community_posts set status = 'deleted', body = '', link_url = null where id = $1`, id)
		return err
	}))
}

// CommunityCommentInput adds a comment or a reply.
type CommunityCommentInput struct {
	Body            string     `json:"body" minLength:"1" maxLength:"4000"`
	ParentCommentID *uuid.UUID `json:"parent_comment_id,omitempty"`
}

// AddComment comments on a post (active members; not on locked posts).
func (s *Service) AddComment(ctx context.Context, postID uuid.UUID, in CommunityCommentInput) (*CommunityCommentDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityCommentDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		p, c, err := s.lockPost(ctx, tx, uid, postID)
		if err != nil {
			return err
		}
		if err := s.requireParticipant(ctx, tx, c); err != nil {
			return err
		}
		if p.Status != "published" || p.Locked {
			return apperr.Rule("comments_closed", "Comments are closed on this post.", nil)
		}
		body, err := cleanField("body.body", in.Body, 1, 4000)
		if err != nil {
			return err
		}
		if textsafe.Links(*body) > maxBodyLinks {
			return tooManyLinks("comment")
		}
		if err := spamCheck(ctx, tx, uid, false); err != nil {
			return err
		}
		var dup bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from community_comments where author_id = $1 and post_id = $2 and body = $3
			and created_at > now() - interval '10 minutes')`, uid, postID, *body).Scan(&dup); err != nil {
			return err
		}
		if dup {
			return apperr.Conflict("You just posted this comment.")
		}
		if in.ParentCommentID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from community_comments where id = $1 and post_id = $2 and status = 'published')`,
				*in.ParentCommentID, postID).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.FieldCode("body.parent_comment_id", "invalid_parent", "Reply to a comment on this post.", nil)
			}
		}
		id := uuid.New()
		if _, err := tx.Exec(ctx, `insert into community_comments (id, post_id, community_id, author_id, parent_comment_id, body) values ($1,$2,$3,$4,$5,$6)`,
			id, postID, p.CommunityID, uid, in.ParentCommentID, *body); err != nil {
			return err
		}
		if err := outbox.Emit(ctx, tx, outbox.Event{Type: EventCommentCreated, AggregateType: "community_comment", AggregateID: id, UserID: &uid}); err != nil {
			return err
		}
		list, err := s.comments(ctx, tx, uid, p.CommunityID, postID)
		if err != nil {
			return err
		}
		for i := range list {
			if list[i].ID == id {
				out = &list[i]
			}
		}
		return nil
	})
	return out, database.MapError(err)
}

func (s *Service) ownComment(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (uuid.UUID, uuid.UUID, error) {
	var post, comm uuid.UUID
	var authorID *uuid.UUID
	var status string
	if err := tx.QueryRow(ctx, `select post_id, community_id, author_id, status from community_comments where id = $1`, id).Scan(&post, &comm, &authorID, &status); err != nil {
		if database.IsNoRows(err) {
			return uuid.Nil, uuid.Nil, apperr.NotFound("comment")
		}
		return uuid.Nil, uuid.Nil, err
	}
	if authorID == nil || *authorID != uid {
		return uuid.Nil, uuid.Nil, apperr.Forbidden()
	}
	if status != "published" {
		return uuid.Nil, uuid.Nil, apperr.Rule("comment_locked", "This comment can no longer be changed.", nil)
	}
	return post, comm, nil
}

// UpdateComment edits the author's own comment.
func (s *Service) UpdateComment(ctx context.Context, id uuid.UUID, body string) (*CommunityCommentDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityCommentDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		post, comm, err := s.ownComment(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		c, err := loadCommunity(ctx, tx, uid, comm)
		if err != nil {
			return err
		}
		if err := s.requireParticipant(ctx, tx, c); err != nil {
			return err
		}
		b, err := cleanField("body.body", body, 1, 4000)
		if err != nil {
			return err
		}
		if textsafe.Links(*b) > maxBodyLinks {
			return tooManyLinks("comment")
		}
		if _, err := tx.Exec(ctx, `update community_comments set body = $2, edited_at = now() where id = $1`, id, *b); err != nil {
			return err
		}
		list, err := s.comments(ctx, tx, uid, comm, post)
		if err != nil {
			return err
		}
		for i := range list {
			if list[i].ID == id {
				out = &list[i]
			}
		}
		return nil
	})
	return out, database.MapError(err)
}

// DeleteComment deletes the author's own comment (replies stay).
func (s *Service) DeleteComment(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, _, err := s.ownComment(ctx, tx, uid, id); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `update community_comments set status = 'deleted', body = '[deleted]' where id = $1`, id)
		return err
	}))
}

// React adds (on) or removes (off) the caller's reaction to a post or
// comment, answering the counts and the caller's own reactions.
func (s *Service) React(ctx context.Context, postID, commentID *uuid.UUID, kind string, on bool) (*CommunityReactionsDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out CommunityReactionsDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var comm uuid.UUID
		var status string
		var q string
		var target uuid.UUID
		if postID != nil {
			q, target = `select community_id, status from community_posts where id = $1`, *postID
		} else {
			q, target = `select community_id, status from community_comments where id = $1`, *commentID
		}
		if err := tx.QueryRow(ctx, q, target).Scan(&comm, &status); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("content")
			}
			return err
		}
		c, err := loadCommunity(ctx, tx, uid, comm)
		if err != nil {
			return err
		}
		if on {
			if err := s.requireParticipant(ctx, tx, c); err != nil {
				return err
			}
			if status != "published" {
				return apperr.Rule("content_unavailable", "This content is not available.", nil)
			}
			if _, err := tx.Exec(ctx, `insert into community_reactions (community_id, user_id, post_id, comment_id, kind) values ($1,$2,$3,$4,$5)
				on conflict do nothing`, comm, uid, postID, commentID, kind); err != nil {
				return err
			}
		} else if _, err := tx.Exec(ctx, `delete from community_reactions where user_id = $1 and kind = $2
			and (($3::uuid is not null and post_id = $3) or ($4::uuid is not null and comment_id = $4))`, uid, kind, postID, commentID); err != nil {
			return err
		}
		out.CommunityReactionCounts, out.MyReactions, err = reactions(ctx, tx, uid, postID, commentID)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// Vote replaces the caller's votes on a poll (until it closes).
func (s *Service) Vote(ctx context.Context, postID uuid.UUID, options []uuid.UUID) (*CommunityPollDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CommunityPollDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		p, c, err := s.lockPost(ctx, tx, uid, postID)
		if err != nil {
			return err
		}
		if err := s.requireParticipant(ctx, tx, c); err != nil {
			return err
		}
		if p.Poll == nil || p.Status != "published" {
			return apperr.NotFound("poll")
		}
		if p.Poll.Closed {
			return apperr.Rule("poll_closed", "This poll is closed.", nil)
		}
		if len(options) == 0 || (!p.Poll.AllowMultiple && len(options) > 1) {
			return apperr.FieldCode("body.option_ids", "too_many", "Choose one option"+map[bool]string{true: " or more.", false: "."}[p.Poll.AllowMultiple],
				map[string]string{"max": "1"})
		}
		valid := map[uuid.UUID]bool{}
		for _, o := range p.Poll.Options {
			valid[o.ID] = true
		}
		seen := map[uuid.UUID]bool{}
		for _, o := range options {
			if !valid[o] || seen[o] {
				return apperr.FieldCode("body.option_ids", "invalid_option", "Choose options from this poll, each once.", nil)
			}
			seen[o] = true
		}
		if _, err := tx.Exec(ctx, `delete from community_poll_votes where poll_id = $1 and user_id = $2`, p.Poll.ID, uid); err != nil {
			return err
		}
		for _, o := range options {
			if _, err := tx.Exec(ctx, `insert into community_poll_votes (poll_id, option_id, community_id, user_id) values ($1,$2,$3,$4)`,
				p.Poll.ID, o, p.CommunityID, uid); err != nil {
				return err
			}
		}
		out, err = s.poll(ctx, tx, uid, postID)
		return err
	})
	return out, database.MapError(err)
}
