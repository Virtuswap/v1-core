class migrationUtils {
  static twoDigits(d) {
    if (0 <= d && d < 10) return "0" + d.toString();
    if (-10 < d && d < 0) return "-0" + (-1 * d).toString();
    return d.toString();
  }

  static SQLDate(datetime) {
    if (typeof datetime == "number" || typeof datetime == "string") {
      datetime = new Date(datetime);
    }
    return (
      datetime.getFullYear() +
      "-" +
      this.twoDigits(1 + datetime.getMonth()) +
      "-" +
      this.twoDigits(datetime.getDate()) +
      " " +
      this.twoDigits(datetime.getHours()) +
      ":" +
      this.twoDigits(datetime.getMinutes()) +
      ":" +
      this.twoDigits(datetime.getSeconds())
    );
  }

  static SQLNow() {
    return this.SQLDate(new Date());
  }

  static generateTokenSQL(tokenName, sym, address, enviroment) {
    return `INSERT INTO vswap.tokens
            (tokenName,
            symbol,
            address,
            enviroment)
            VALUES('${tokenName}','${sym}','${address}',${enviroment})`;
  }

  static generateVersionsSQL(adderss, abi, type, env) {
    return (
      "INSERT INTO `vswap`.`versions` (`address`, `abi`, `type`, `timestamp`,`enviroment`) VALUES ('" +
      adderss +
      "','" +
      JSON.stringify(abi) +
      "','" +
      type +
      "', '" +
      this.SQLNow() +
      "'," +
      env +
      ");"
    );
  }
}

module.exports = migrationUtils;
