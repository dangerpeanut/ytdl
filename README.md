# ytdl
A perl daemon that wraps [youtube-dl](https://rg3.github.io/youtube-dl/) for unattended downloading of url lists.

### REQUIREMENTS

* *Python*
    * [youtube-dl](https://rg3.github.io/youtube-dl/)
* *Perl*
    * IO::Compress::Gzip
    * File::Copy
    * Getopt::Long
    * Data::Validate::URI
    * Config::Tiny

### Installation

1. Clone the repository to your desired destination.
2. Make `ytdl.pl` executable: `chmod +x ytdl.pl`
3. Open `ytdl.ini` in a text editor and configure it.
4. Copy `ytdl.ini` to `/home/youruser/.ytdl.ini`
5. Enable the script by changing `$disablescript` in `ytdl.pl` from `true` to *`false`*.

### Usage

`ytdl [OPTIONS] &`

1. `ytdl -d`<BR>ytdl will slurp a list of [youtube-dl](https://rg3.github.io/youtube-dl/) friendly urls from the list file and begin iterating through this list. Depending on the length of the list or type of urls ( playlists ), this might take a while.
2. `ytdl -a [URLS]`<BR>ytdl will take the list of URLS after the `-a` option and add these to the list to be downloaded.

*If __ytdl__ finds that the list file is empty, it checks to see if the log needs rotation and then sleeps. This loops until killed or SIGINT.*

The intended usage is with the `-d` option.

### Options

* `-a [URLS]` Add urls to list.
* `-t` Testing mode.<BR>Does not download files or clear download list. Also prints script variables.
* `-d` Daemonizes.<BR>Redirects output to log file and closes input. *Intended usage.*

### Configuration

This script uses a config file with named blocks with key=value pairs.

#### Example

`[block1]`<br>
`option1a=1`<br>
`option1b='/home/user/file.ext'`<br><br>
`[block2]`<br>
`option2a=1`<br>
`option2b='/home/user/file.ext'`

There is a config file provided with default values.

- `files`

    * `list`<BR>Full path to file with [youtube-dl](https://rg3.github.io/youtube-dl/) links for *ytdl* to download. This is also the file *ytdl* will add links to. Called the "working" list. This file should only have one link per line.
    * `log`<BR> Full path to log file for *ytdl* to use.
    * `tmplist`<BR>Full path to temporary list. When *ytdl* find links in the working list, it will copy the working list to this file. If *ytdl* crashes, you can restore from this.
    * `tmplog`<BR>Log file for *ytdl* to use while it rotates the working log file.


- `dirs` *__IMPORTANT__ All directory values are assumed to end in a slash.* <BR> If you __DO NOT__ end these directories with a slash, bad things can happen. Please do the needful and put slashes on the end of your folders.

    * `logs` The folder to use for logging.
    * `tmp` *Deprecated*
    * `done` The folder that youtube-dl should download to.


- `option`

    * `rate` The [--limit-rate](https://github.com/rg3/youtube-dl/blob/master/README.md#download-options) value to be passed. At the moment this is *expected*.<BR>*Default: __10M__*
    * `naptime` This is the number of seconds `ytdl` will nap before checking to see if there are links to download.<BR>*Default: __120__*
    * `rotatesize` The log will not be rotated until it is greater than this size in bytes. _**Does not** support short-hand; EG 50k, 4.5m. **Must be** in bytes; EG 50000 4500000_<BR>*Default: __3000000__*
    * `disablescript` This variable checks the user's competence.
    * `ytdlouttemp` This is the [template string](https://github.com/rg3/youtube-dl/blob/master/README.md#output-template) to pass to youtube-dl.<BR>*Default: __%(title)s-%(id)s.%(ext)s__*
    * `ytdlopts` Comma separated list of options to pass to youtube-dl.<BR>* Default: __--yes-playlist,--no-progress,--ignore-errors,--write-description,--write-info-json__*


- `python`

    * `yt-dlbin` The absolute path to your youtube-dl python script.
    * `pyin` The absolute path to your python binary.


## Notes / Considerations

- Playlists

    * If you add a url that points to a playlist, it will download the entire playlist. This script was written with the intent of archival. If you plan to handle a lot of playlist links with this wrapper, I advise you to change the [template string](https://github.com/rg3/youtube-dl/blob/master/README.md#output-template) to something more ideal. Here is an example:<BR><BR>`%(uploader)s/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s`<BR><BR>
    * As a secondary consideration in regards to playlists, this wrapper iterates over each link. It starts a system process for each iteration and waits for it to complete. If the link points to a playlist, youtube-dl builds a list of videos and iterates over those. This means that for long playlists, *ytdl* is going to wait a while for youtube-dl to complete the playlist before moving on.


- Status

    * My favorite way to check the status of the script is to `tail -f file` the log. *ytdl* prints to and outputs the youtube-dl output into this logfile.


- Daemonizing

    * Daemonizing the script will not let go of input. Until I can properly daemonize it, I advise you to call it as `ytdl.pl -d &` from your command shell. It calls `nohup` each time it runs `youtube-dl`.


- Configuration

    * The configuration file is assumed to be in your home folder with the name of `.ytdl.ini`. This can be changed in the script file itself, but it is not supported.


- Future Plans

    * **Throttle Schedule**<BR>It would be neat to have different speeds during different parts of the day or week.<BR><BR>
    * **Proper Daemonization**<BR>Using fork or Proc::Daemon. Would be cool.<BR><BR>
    * **Live Reload**<BR>Instead of stopping the script, have it reload from the ini file on demand.<BR><BR>
    * **Path for youtube-dl**<BR>This should be a config option, but it's not. Is simple. Will do.<BR><BR>
    * **More**<BR> ... <BR><BR>
