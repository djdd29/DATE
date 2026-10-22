
const DATE_DATABASE = {
  url: "https://azivoncenlvwdqcyrjtb.supabase.co",
  functionName: "portal-api",

  async checkConnection() {
    const response = await fetch(
      `${this.url}/functions/v1/${this.functionName}`,
      {
        method: "GET",
        headers: {
          "Content-Type": "application/json"
        }
      }
    );

    if (!response.ok) {
      throw new Error("تعذر الاتصال بقاعدة البيانات");
    }

    const result = await response.json();

    if (result.ok !== true) {
      throw new Error("قاعدة البيانات لم تؤكد الاتصال");
    }

    return result;
  }
};

window.DATE_DATABASE = DATE_DATABASE;
