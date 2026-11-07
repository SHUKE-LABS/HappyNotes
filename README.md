# Happy Notes - Take notes as easily as tweeting
[中文](./README.cn.md)

HappyNotes is a simple yet powerful note-taking app that supports all platforms.

## Why is it called HappyNotes?

The name was inspired by HappyFeed, of which I was a heavy user of the free version. I must say it's quite good if your goal is just to write a diary. Oh, I almost went off-topic recommending HappyFeed, but you're still welcome to use HappyNotes. Happy notes, recording your happy life. What a great vision! But life isn't always sunny, so I also record some other journeys of the mind. Stop! Let's focus on recording more happy moments in life!

## Why not use other existing note-taking software?

Firstly, the free versions of these apps have too many limitations! Another reason is that although I'm a programmer, my product manager dream is still burning! I want to create an app that at least I enjoy using to <del>"prove" myself</del> give back to society.

## What's special about HappyNotes?


### Text is King

HappyNotes allows you to upload photos, but once a photo is successfully uploaded, it becomes part of your note, as a Markdown image text (`![imageTitle](imageUrl)`) format.

### Supports private text, but not private photos

This means that even if a note is private, the photos in it are public. This eliminates the possibility of private photo leaks from the source! Simply don't upload private photos. Remember: The cloud brings convenience but reduces security.

**Creating Notes with the Floating Action Button (FAB):**
- **Home Page**: FAB with badge showing lock icon (🔒) for private notes / globe icon (🌍) for public notes
  - Default visibility is private; can be changed in Settings
- **Memories on a Day Page**: FAB with lock icon badge for adding private notes to that specific date
- **Note Detail Page**: FAB inherits parent note's visibility - creates linked notes (@noteId) with same public/private setting
- Photos are hosted on HappyNotes' image server, and anyone who knows the image URL can access your photos. Important thing to say three times: **Please do not upload private photos. Please do not upload private photos. Please do not upload private photos**.

### Supports viewing notes/diaries by day

- Want to know how you spent your birthday last year? Tap the `My Notes title`, enter a date, and you'll go straight to that day's notes. Want to see the day before? HappyNotes allows you to browse the previous and next day from any day's note page. It's like your paper notebook, flip to a certain day, keep flipping forward for the next day, or backward for the previous day.
- There's actually a bonus here! When you enter a date, besides seeing the notes for that date, HappyNotes also allows you to add any number of additional notes on that day. There's a + button in the bottom right corner of the note list for a particular day. Clicking that button allows you to write a new note for that date. Before submitting, you must select an hour (or click OK to use the current hour). The date will be that day, and the hour will be the one you selected, while minutes and seconds will use the current time. For example, if you're adding a note on the page for January 1, 1989, and you select hour 15 (3 PM) at 12:34:56 current time, the note will be published at 15:34:56 on January 1, 1989. I hope I've made myself clear.

### Supports viewing notes by Tag

- In the note list, tags for each note are listed. Clicking on any tag will show all notes marked with that tag.
- Tap any page title to search or jump to a date. While you can't jump directly to a tag page, you can search for the tag text.
- Long press any page title to see a Tag cloud, where you can click any tag to view all notes with that tag.
- **Search ↔ Tag switching**: When viewing search results, if your search term is in valid tag format (no spaces), a "View as Tag" button appears in the top-right corner to switch to tag view. Similarly, when viewing notes by tag, you can tap the search icon to switch to search results for that tag text.

### Supports jumping to notes by ID

- In any note list, you can long press on the metadata row (the blue line with date, time and note ID) to open a dialog for jumping to a specific note by its ID.
- Simply enter the note ID number and press "Go" to navigate directly to that note.
- This feature provides quick access to specific notes when you know their ID, useful for referencing notes from external links or bookmarks.

### Public note permalinks

Public notes can be shared with the GitHub Pages-safe URL format `https://happynotes.shukebeta.com/#/note/{id}`. The page is read-only and can be opened without signing in; Markdown notes use the Markdown renderer and plain notes are shown as text.

Legacy `/note/{id}` links are handled by the GitHub Pages `404.html` compatibility page: matching paths first return the expected HTTP 404 response, then replace the address with `/#/note/{id}` so the Flutter app can display the note. Only `/note/<decimal-id>` paths redirect; other missing paths remain on the normal not-found page.

Private, soft-deleted, malformed, and nonexistent IDs all show the same not-found state. The public endpoint never exposes private note content or account controls.

### Supports uploading or pasting images

- Currently, you need to enable Markdown support in the note editing interface to upload images. Just tap the Markdown switch below the edit box to turn this feature on/off. You can also turn Markdown support on/off in Settings -> Markdown.

### Supports syncing notes to Telegram channels

You can choose to sync all notes, or only public notes, or only private notes, or only notes with specific Tags to a Telegram channel. I don't recommend syncing your private notes to a public Telegram channel. However, if you insist on doing so, HappyNotes won't stop you. I usually create a private channel to sync all my notes, which serves as a backup.

### Supports syncing specified notes to Mastodon

You can choose to sync all notes, or only public notes, or only notes with the Mastodon tag to a Mastodon instance. Private notes will be published as private toots. Notes longer than 500 characters will be published as long images.

- If you change a public note to private or vice versa, the originally synced toot will be deleted and reposted. Therefore, the Mastodon timeline may not be consistent with your note timeline.
- Since Mastodon doesn't support Markdown, the first four images in Markdown notes will be synced to the media server of the Mastodon instance. To some extent, this Mastodon instance serves as a backup for your note images.

### Supports "Discovering" others' public notes

This feature is currently only available on Web, maybe later it will be opened to native Apps.

### Other tips

- **Edit Notes**: Double-tap a note to make changes.
- **Tags**: Create tags by adding `#example_tag` in your notes.
- **Note Details**: Tap creation time or `View more` for details.
- **Navigation**: Long press page numbers to jump to a specific page.
- **Settings**:
  - Adjust page size.
  - Set your timezone.
  - Enable Markdown support.
  - Set default note visibility (private notes by default).

## Join Our Community

Connect with us on Telegram for support and to share experiences:

[Happy Notes Support Group](https://t.me/happynotes_support)

Let's support each other and make the most of HappyNotes!

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.


