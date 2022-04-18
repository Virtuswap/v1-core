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

  static generateVersionsSQL(adderss, abi, type) {
    return (
      "INSERT INTO `vswap`.`versions` (`address`, `abi`, `type`, `timestamp`) VALUES ('" +
      adderss +
      "','" +
      JSON.stringify(abi) +
      "','" +
      type +
      "', '" +
      this.SQLNow() +
      "');"
    );
  }
}

module.exports = migrationUtils;