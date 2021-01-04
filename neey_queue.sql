-- Struktura tabeli dla tabeli `neey_chars`
--

CREATE TABLE `neey_chars` (
  `identifier` varchar(255) NOT NULL,
  `limit` int(2) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user_lastcharacter` (
  `license` varchar(255) NOT NULL,
  `charid` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
