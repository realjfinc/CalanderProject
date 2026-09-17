/// The full NBA/NFL/NHL/MLB rosters, hand-verified against the live API
/// (`searchteams.php`/`lookupteam.php` on TheSportsDB's free test key) --
/// every id below is confirmed to return that exact team.
///
/// This exists because `searchteams.php?t=<query>` (TheSportsDB's only
/// team-search endpoint on this key) matches close to the *exact* team
/// name, not a substring or nickname: searching "Lakers" alone returns an
/// unrelated NCAA team, not "Los Angeles Lakers" -- only the full official
/// name reliably finds it. [TheSportsDbClient.searchTeams] uses this list
/// as a local substring-matchable index (so "lakers" -> "Los Angeles
/// Lakers" works), resolving a match to live data with [idTeam] via
/// `lookupteam.php`, a single-item lookup that (unlike the list endpoints
/// this free key mostly restricts) actually returns real per-id data.
class MajorLeagueTeam {
  const MajorLeagueTeam(this.name, this.idTeam, this.league);

  final String name;
  final String idTeam;
  final String league;
}

const List<MajorLeagueTeam> majorLeagueTeams = [
  // NBA
  MajorLeagueTeam('Atlanta Hawks', '134880', 'NBA'),
  MajorLeagueTeam('Boston Celtics', '134860', 'NBA'),
  MajorLeagueTeam('Brooklyn Nets', '134861', 'NBA'),
  MajorLeagueTeam('Charlotte Hornets', '134881', 'NBA'),
  MajorLeagueTeam('Chicago Bulls', '134870', 'NBA'),
  MajorLeagueTeam('Cleveland Cavaliers', '134871', 'NBA'),
  MajorLeagueTeam('Dallas Mavericks', '134875', 'NBA'),
  MajorLeagueTeam('Denver Nuggets', '134885', 'NBA'),
  MajorLeagueTeam('Detroit Pistons', '134872', 'NBA'),
  MajorLeagueTeam('Golden State Warriors', '134865', 'NBA'),
  MajorLeagueTeam('Houston Rockets', '134876', 'NBA'),
  MajorLeagueTeam('Indiana Pacers', '134873', 'NBA'),
  MajorLeagueTeam('Los Angeles Clippers', '134866', 'NBA'),
  MajorLeagueTeam('Los Angeles Lakers', '134867', 'NBA'),
  MajorLeagueTeam('Memphis Grizzlies', '134877', 'NBA'),
  MajorLeagueTeam('Miami Heat', '134882', 'NBA'),
  MajorLeagueTeam('Milwaukee Bucks', '134874', 'NBA'),
  MajorLeagueTeam('Minnesota Timberwolves', '134886', 'NBA'),
  MajorLeagueTeam('New Orleans Pelicans', '134878', 'NBA'),
  MajorLeagueTeam('New York Knicks', '134862', 'NBA'),
  MajorLeagueTeam('Oklahoma City Thunder', '134887', 'NBA'),
  MajorLeagueTeam('Orlando Magic', '134883', 'NBA'),
  MajorLeagueTeam('Philadelphia 76ers', '134863', 'NBA'),
  MajorLeagueTeam('Phoenix Suns', '134868', 'NBA'),
  MajorLeagueTeam('Portland Trail Blazers', '134888', 'NBA'),
  MajorLeagueTeam('Sacramento Kings', '134869', 'NBA'),
  MajorLeagueTeam('San Antonio Spurs', '134879', 'NBA'),
  MajorLeagueTeam('Toronto Raptors', '134864', 'NBA'),
  MajorLeagueTeam('Utah Jazz', '134889', 'NBA'),
  MajorLeagueTeam('Washington Wizards', '134884', 'NBA'),

  // NFL
  MajorLeagueTeam('Arizona Cardinals', '134946', 'NFL'),
  MajorLeagueTeam('Atlanta Falcons', '134942', 'NFL'),
  MajorLeagueTeam('Baltimore Ravens', '134922', 'NFL'),
  MajorLeagueTeam('Buffalo Bills', '134918', 'NFL'),
  MajorLeagueTeam('Carolina Panthers', '134943', 'NFL'),
  MajorLeagueTeam('Chicago Bears', '134938', 'NFL'),
  MajorLeagueTeam('Cincinnati Bengals', '134923', 'NFL'),
  MajorLeagueTeam('Cleveland Browns', '134924', 'NFL'),
  MajorLeagueTeam('Dallas Cowboys', '134934', 'NFL'),
  MajorLeagueTeam('Denver Broncos', '134930', 'NFL'),
  MajorLeagueTeam('Detroit Lions', '134939', 'NFL'),
  MajorLeagueTeam('Green Bay Packers', '134940', 'NFL'),
  MajorLeagueTeam('Houston Texans', '134926', 'NFL'),
  MajorLeagueTeam('Indianapolis Colts', '134927', 'NFL'),
  MajorLeagueTeam('Jacksonville Jaguars', '134928', 'NFL'),
  MajorLeagueTeam('Kansas City Chiefs', '134931', 'NFL'),
  MajorLeagueTeam('Las Vegas Raiders', '134932', 'NFL'),
  MajorLeagueTeam('Los Angeles Chargers', '135908', 'NFL'),
  MajorLeagueTeam('Los Angeles Rams', '135907', 'NFL'),
  MajorLeagueTeam('Miami Dolphins', '134919', 'NFL'),
  MajorLeagueTeam('Minnesota Vikings', '134941', 'NFL'),
  MajorLeagueTeam('New England Patriots', '134920', 'NFL'),
  MajorLeagueTeam('New Orleans Saints', '134944', 'NFL'),
  MajorLeagueTeam('New York Giants', '134935', 'NFL'),
  MajorLeagueTeam('New York Jets', '134921', 'NFL'),
  MajorLeagueTeam('Philadelphia Eagles', '134936', 'NFL'),
  MajorLeagueTeam('Pittsburgh Steelers', '134925', 'NFL'),
  MajorLeagueTeam('San Francisco 49ers', '134948', 'NFL'),
  MajorLeagueTeam('Seattle Seahawks', '134949', 'NFL'),
  MajorLeagueTeam('Tampa Bay Buccaneers', '134945', 'NFL'),
  MajorLeagueTeam('Tennessee Titans', '134929', 'NFL'),
  MajorLeagueTeam('Washington Commanders', '134937', 'NFL'),

  // NHL
  MajorLeagueTeam('Anaheim Ducks', '134846', 'NHL'),
  MajorLeagueTeam('Boston Bruins', '134830', 'NHL'),
  MajorLeagueTeam('Buffalo Sabres', '134831', 'NHL'),
  MajorLeagueTeam('Calgary Flames', '134848', 'NHL'),
  MajorLeagueTeam('Carolina Hurricanes', '134838', 'NHL'),
  MajorLeagueTeam('Chicago Blackhawks', '134854', 'NHL'),
  MajorLeagueTeam('Colorado Avalanche', '134855', 'NHL'),
  MajorLeagueTeam('Columbus Blue Jackets', '134839', 'NHL'),
  MajorLeagueTeam('Dallas Stars', '134856', 'NHL'),
  MajorLeagueTeam('Detroit Red Wings', '134832', 'NHL'),
  MajorLeagueTeam('Edmonton Oilers', '134849', 'NHL'),
  MajorLeagueTeam('Florida Panthers', '134833', 'NHL'),
  MajorLeagueTeam('Los Angeles Kings', '134852', 'NHL'),
  MajorLeagueTeam('Minnesota Wild', '134857', 'NHL'),
  MajorLeagueTeam('Montreal Canadiens', '134834', 'NHL'),
  MajorLeagueTeam('Nashville Predators', '134858', 'NHL'),
  MajorLeagueTeam('New Jersey Devils', '134840', 'NHL'),
  MajorLeagueTeam('New York Islanders', '134841', 'NHL'),
  MajorLeagueTeam('New York Rangers', '134842', 'NHL'),
  MajorLeagueTeam('Ottawa Senators', '134835', 'NHL'),
  MajorLeagueTeam('Philadelphia Flyers', '134843', 'NHL'),
  MajorLeagueTeam('Pittsburgh Penguins', '134844', 'NHL'),
  MajorLeagueTeam('San Jose Sharks', '134853', 'NHL'),
  MajorLeagueTeam('Seattle Kraken', '140082', 'NHL'),
  MajorLeagueTeam('St. Louis Blues', '134859', 'NHL'),
  MajorLeagueTeam('Tampa Bay Lightning', '134836', 'NHL'),
  MajorLeagueTeam('Toronto Maple Leafs', '134837', 'NHL'),
  MajorLeagueTeam('Utah Mammoth', '148494', 'NHL'),
  MajorLeagueTeam('Vancouver Canucks', '134850', 'NHL'),
  MajorLeagueTeam('Vegas Golden Knights', '135913', 'NHL'),
  MajorLeagueTeam('Washington Capitals', '134845', 'NHL'),
  MajorLeagueTeam('Winnipeg Jets', '134851', 'NHL'),

  // MLB
  MajorLeagueTeam('Arizona Diamondbacks', '135267', 'MLB'),
  MajorLeagueTeam('Athletics', '135261', 'MLB'),
  MajorLeagueTeam('Atlanta Braves', '135268', 'MLB'),
  MajorLeagueTeam('Baltimore Orioles', '135251', 'MLB'),
  MajorLeagueTeam('Boston Red Sox', '135252', 'MLB'),
  MajorLeagueTeam('Chicago Cubs', '135269', 'MLB'),
  MajorLeagueTeam('Chicago White Sox', '135253', 'MLB'),
  MajorLeagueTeam('Cincinnati Reds', '135270', 'MLB'),
  MajorLeagueTeam('Cleveland Guardians', '135254', 'MLB'),
  MajorLeagueTeam('Colorado Rockies', '135271', 'MLB'),
  MajorLeagueTeam('Detroit Tigers', '135255', 'MLB'),
  MajorLeagueTeam('Houston Astros', '135256', 'MLB'),
  MajorLeagueTeam('Kansas City Royals', '135257', 'MLB'),
  MajorLeagueTeam('Los Angeles Angels', '135258', 'MLB'),
  MajorLeagueTeam('Los Angeles Dodgers', '135272', 'MLB'),
  MajorLeagueTeam('Miami Marlins', '135273', 'MLB'),
  MajorLeagueTeam('Milwaukee Brewers', '135274', 'MLB'),
  MajorLeagueTeam('Minnesota Twins', '135259', 'MLB'),
  MajorLeagueTeam('New York Mets', '135275', 'MLB'),
  MajorLeagueTeam('New York Yankees', '135260', 'MLB'),
  MajorLeagueTeam('Philadelphia Phillies', '135276', 'MLB'),
  MajorLeagueTeam('Pittsburgh Pirates', '135277', 'MLB'),
  MajorLeagueTeam('San Diego Padres', '135278', 'MLB'),
  MajorLeagueTeam('San Francisco Giants', '135279', 'MLB'),
  MajorLeagueTeam('Seattle Mariners', '135262', 'MLB'),
  MajorLeagueTeam('St. Louis Cardinals', '135280', 'MLB'),
  MajorLeagueTeam('Tampa Bay Rays', '135263', 'MLB'),
  MajorLeagueTeam('Texas Rangers', '135264', 'MLB'),
  MajorLeagueTeam('Toronto Blue Jays', '135265', 'MLB'),
  MajorLeagueTeam('Washington Nationals', '135281', 'MLB'),
];
